import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as assets from 'aws-cdk-lib/aws-ecr-assets';


import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as path from 'path';

export class InfraStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const backendAsset = new assets.DockerImageAsset(this, 'BackendAsset', {
      directory: path.join(__dirname, '../../backend'),
      platform: assets.Platform.LINUX_AMD64,
    });

    const table = new dynamodb.Table(this, 'PantaRequestsTable', {
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

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
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const userPoolClient = userPool.addClient('PantaMobileAppClient', {
      userPoolClientName: 'PantaMobileAppClient',
      authFlows: {
        userSrp: true,
      },
    });

    const taskExecutionRole = new iam.Role(this, 'PantaExpressExecutionRole', {
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName(
          'service-role/AmazonECSTaskExecutionRolePolicy',
        ),
      ],
    });

    const infrastructureRole = new iam.Role(this, 'PantaExpressInfrastructureRole', {
      assumedBy: new iam.ServicePrincipal('ecs.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName(
          'service-role/AmazonECSInfrastructureRoleforExpressGatewayServices',
        ),
      ],
    });

    const taskRole = new iam.Role(this, 'PantaExpressTaskRole', {
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
    });
    table.grantReadWriteData(taskRole);

    const logGroup = new logs.LogGroup(this, 'PantaExpressLogGroup', {
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const expressService = new ecs.CfnExpressGatewayService(this, 'PantaGoBackendService', {
      serviceName: 'panta-go-backend',
      cpu: '256',
      memory: '512',
      executionRoleArn: taskExecutionRole.roleArn,
      infrastructureRoleArn: infrastructureRole.roleArn,
      taskRoleArn: taskRole.roleArn,
      healthCheckPath: '/health',
      primaryContainer: {
        image: backendAsset.imageUri,
        containerPort: 8080,
        environment: [
          { name: 'PORT', value: '8080' },
          { name: 'TABLE_NAME', value: table.tableName },
          { name: 'AWS_REGION', value: this.region },
          { name: 'COGNITO_USER_POOL_ID', value: userPool.userPoolId },
          { name: 'COGNITO_CLIENT_ID', value: userPoolClient.userPoolClientId },
        ],
        awsLogsConfiguration: {
          logGroup: logGroup.logGroupName,
          logStreamPrefix: 'PantaGoBackendService',
        },
      },
      scalingTarget: {
        minTaskCount: 1,
        maxTaskCount: 1,
      },
    });
    expressService.node.addDependency(backendAsset);

    new cdk.CfnOutput(this, 'UserPoolId', {
      value: userPool.userPoolId,
      description: 'Cognito User Pool ID',
    });

    new cdk.CfnOutput(this, 'UserPoolClientId', {
      value: userPoolClient.userPoolClientId,
      description: 'Cognito User Pool Client ID',
    });

    new cdk.CfnOutput(this, 'ServiceUrl', {
      value: expressService.attrEndpoint,
      description: 'The URL of the ECS Express service',
      exportName: 'PantaGoBackendServiceUrl',
    });

    new cdk.CfnOutput(this, 'ExpressServiceArn', {
      value: expressService.attrServiceArn,
      description: 'The ARN of the ECS Express service',
    });
  }
}
