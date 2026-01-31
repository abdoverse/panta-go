import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as assets from 'aws-cdk-lib/aws-ecr-assets';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as ecs_patterns from 'aws-cdk-lib/aws-ecs-patterns';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as path from 'path';
import * as cognito from 'aws-cdk-lib/aws-cognito';

export class InfraStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Define the Docker Asset for the backend
    // This builds the Dockerfile located in ../../backend
    const backendAsset = new assets.DockerImageAsset(this, 'BackendAsset', {
      directory: path.join(__dirname, '../../backend'),
      platform: assets.Platform.LINUX_AMD64,
    });

    // Create a VPC (required for ECS)
    // Using a cheap configuration: max 2 AZs, no NAT Gateways (public subnets only) to save cost
    const vpc = new ec2.Vpc(this, 'PantaVpc', {
      maxAzs: 2,
      natGateways: 0,
      subnetConfiguration: [
        {
          name: 'Public',
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
      ],
    });

    // Create an ECS Cluster
    const cluster = new ecs.Cluster(this, 'PantaCluster', {
      vpc: vpc,
    });

    // Create DynamoDB Table
    const table = new dynamodb.Table(this, 'PantaRequestsTable', {
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY, // For dev/demo only
    });

    // Create a Fargate Service with an Application Load Balancer
    // This serves as the equivalent to App Runner for regions where App Runner is unavailable
    const fargateService = new ecs_patterns.ApplicationLoadBalancedFargateService(this, 'PantaGoBackendService', {
      cluster: cluster,
      cpu: 256, // .25 vCPU
      memoryLimitMiB: 512, // 512 MB
      desiredCount: 1,
      taskImageOptions: {
        image: ecs.ContainerImage.fromDockerImageAsset(backendAsset),
        containerPort: 8080,
        environment: {
            PORT: '8080',
            TABLE_NAME: table.tableName,
            AWS_REGION: this.region,
        },
      },
      publicLoadBalancer: true,
      assignPublicIp: true, // Needed because we have no NAT Gateway
    });

    // Grant DynamoDB permissions to the Fargate service
    table.grantReadWriteData(fargateService.taskDefinition.taskRole);

    // ========================================================================
    // COGNITO AUTHENTICATION
    // ========================================================================

    const userPool = new cognito.UserPool(this, 'PantaUserPool', {
      userPoolName: 'PantaUserPool',
      selfSignUpEnabled: true,
      signInAliases: {
        email: true,
        username: true,
      },
      autoVerify: { email: true },
      passwordPolicy: {
        minLength: 8,
        requireLowercase: true,
        requireUppercase: true,
        requireDigits: true,
      },
      removalPolicy: cdk.RemovalPolicy.DESTROY, // For dev
    });

    const userPoolClient = userPool.addClient('PantaMobileAppClient', {
      userPoolClientName: 'PantaMobileAppClient',
      authFlows: {
        userSrp: true,
      },
    });

    // Pass Cognito details to Backend (for token verification if needed locally)
    const backendContainer = fargateService.taskDefinition.defaultContainer;
    if (backendContainer) {
        backendContainer.addEnvironment('COGNITO_USER_POOL_ID', userPool.userPoolId);
        backendContainer.addEnvironment('COGNITO_CLIENT_ID', userPoolClient.userPoolClientId);
        // Needed to fetch public keys (JWKS) to verify tokens
        backendContainer.addEnvironment('AWS_REGION', this.region);
    }

    // Output Cognito Details for Mobile App
    new cdk.CfnOutput(this, 'UserPoolId', {
      value: userPool.userPoolId,
      description: 'Cognito User Pool ID',
    });

    new cdk.CfnOutput(this, 'UserPoolClientId', {
      value: userPoolClient.userPoolClientId,
      description: 'Cognito User Pool Client ID',
    });

    // Configure Health Check
    fargateService.targetGroup.configureHealthCheck({
      path: '/health',
    });

    // Output the Service URL
    new cdk.CfnOutput(this, 'ServiceUrl', {
      value: `http://${fargateService.loadBalancer.loadBalancerDnsName}`,
      description: 'The URL of the Fargate service',
      exportName: 'PantaGoBackendServiceUrl',
    });
  }
}
