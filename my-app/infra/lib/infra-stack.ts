import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as assets from 'aws-cdk-lib/aws-ecr-assets';


import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cr from 'aws-cdk-lib/custom-resources';
import * as path from 'path';

export class InfraStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const requestsTableName = 'panta-go-requests';
    const requestImagesBucketName = 'panta-go-request-images';
    const backendCpu = '256';
    const backendMemory = '512';
    const steadyStateTaskCount = 1;
    const maxTaskCount = 2;
    const logRetentionDays = logs.RetentionDays.ONE_DAY;
    const deploymentMaximumPercent = 100;
    const deploymentMinimumHealthyPercent = 0;

    const backendAsset = new assets.DockerImageAsset(this, 'BackendAsset', {
      directory: path.join(__dirname, '../../backend'),
      platform: assets.Platform.LINUX_AMD64,
    });

    const table = new dynamodb.Table(this, 'StaticPantaRequestsTable', {
      tableName: requestsTableName,
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });
    table.addGlobalSecondaryIndex({
      indexName: 'requests-by-creator',
      partitionKey: { name: 'creatorId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'scheduledFrom', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });
    table.addGlobalSecondaryIndex({
      indexName: 'requests-by-status',
      partitionKey: { name: 'status', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'scheduledFrom', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });
    table.addGlobalSecondaryIndex({
      indexName: 'requests-by-helper',
      partitionKey: { name: 'helperId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'scheduledFrom', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    const requestImagesBucket = new s3.Bucket(this, 'StaticPantaRequestImagesBucket', {
      bucketName: requestImagesBucketName,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      objectOwnership: s3.ObjectOwnership.BUCKET_OWNER_ENFORCED,
      cors: [
        {
          allowedMethods: [s3.HttpMethods.GET, s3.HttpMethods.HEAD],
          allowedOrigins: ['*'],
          allowedHeaders: ['*'],
          maxAge: 3000,
        },
      ],
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      versioned: true,
      lifecycleRules: [
        {
          abortIncompleteMultipartUploadAfter: cdk.Duration.days(7),
        },
      ],
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

    const firebaseServiceAccountSecret = secretsmanager.Secret.fromSecretNameV2(
      this,
      'FirebaseServiceAccountSecret',
      'panta-go/firebase-service-account',
    );

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
    requestImagesBucket.grantReadWrite(taskRole);
    firebaseServiceAccountSecret.grantRead(taskExecutionRole);

    const logGroup = new logs.LogGroup(this, 'PantaExpressLogGroup', {
      retention: logRetentionDays,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const expressService = new ecs.CfnExpressGatewayService(this, 'PantaGoBackendService', {
      serviceName: 'panta-go-backend',
      // ECS Express / Fargate already runs at the smallest supported task size.
      cpu: backendCpu,
      memory: backendMemory,
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
          { name: 'IMAGE_BUCKET_NAME', value: requestImagesBucket.bucketName },
          { name: 'AWS_REGION', value: this.region },
          { name: 'COGNITO_USER_POOL_ID', value: userPool.userPoolId },
          { name: 'COGNITO_CLIENT_ID', value: userPoolClient.userPoolClientId },
        ],
        secrets: [
          {
            name: 'FIREBASE_SERVICE_ACCOUNT_JSON',
            valueFrom: firebaseServiceAccountSecret.secretArn,
          },
        ],
        awsLogsConfiguration: {
          logGroup: logGroup.logGroupName,
          logStreamPrefix: 'PantaGoBackendService',
        },
      },
      scalingTarget: {
        minTaskCount: steadyStateTaskCount,
        maxTaskCount,
      },
    });
    expressService.node.addDependency(backendAsset);

    const deploymentTuningVersion = backendAsset.imageUri;
    const managedTargetGroupArn = cdk.Fn.select(
      0,
      cdk.Token.asList(
        expressService.getAtt('ECSManagedResourceArns.IngressPath.TargetGroupArns'),
      ),
    );

    const tuneManagedTargetGroupHealthCheck = new cr.AwsCustomResource(
      this,
      'TuneManagedTargetGroupHealthCheck',
      {
        onCreate: {
          service: 'ELBv2',
          action: 'modifyTargetGroup',
          parameters: {
            TargetGroupArn: managedTargetGroupArn,
            HealthCheckPath: '/health',
            HealthCheckIntervalSeconds: 5,
            HealthCheckTimeoutSeconds: 4,
            HealthyThresholdCount: 2,
            UnhealthyThresholdCount: 2,
          },
          physicalResourceId: cr.PhysicalResourceId.of(
            `target-group-health-${deploymentTuningVersion}`,
          ),
        },
        onUpdate: {
          service: 'ELBv2',
          action: 'modifyTargetGroup',
          parameters: {
            TargetGroupArn: managedTargetGroupArn,
            HealthCheckPath: '/health',
            HealthCheckIntervalSeconds: 5,
            HealthCheckTimeoutSeconds: 4,
            HealthyThresholdCount: 2,
            UnhealthyThresholdCount: 2,
          },
          physicalResourceId: cr.PhysicalResourceId.of(
            `target-group-health-${deploymentTuningVersion}`,
          ),
        },
        policy: cr.AwsCustomResourcePolicy.fromSdkCalls({
          resources: cr.AwsCustomResourcePolicy.ANY_RESOURCE,
        }),
      },
    );

    const tuneManagedTargetGroupDraining = new cr.AwsCustomResource(
      this,
      'TuneManagedTargetGroupDraining',
      {
        onCreate: {
          service: 'ELBv2',
          action: 'modifyTargetGroupAttributes',
          parameters: {
            TargetGroupArn: managedTargetGroupArn,
            Attributes: [
              {
                Key: 'deregistration_delay.timeout_seconds',
                Value: '15',
              },
            ],
          },
          physicalResourceId: cr.PhysicalResourceId.of(
            `target-group-drain-${deploymentTuningVersion}`,
          ),
        },
        onUpdate: {
          service: 'ELBv2',
          action: 'modifyTargetGroupAttributes',
          parameters: {
            TargetGroupArn: managedTargetGroupArn,
            Attributes: [
              {
                Key: 'deregistration_delay.timeout_seconds',
                Value: '15',
              },
            ],
          },
          physicalResourceId: cr.PhysicalResourceId.of(
            `target-group-drain-${deploymentTuningVersion}`,
          ),
        },
        policy: cr.AwsCustomResourcePolicy.fromSdkCalls({
          resources: cr.AwsCustomResourcePolicy.ANY_RESOURCE,
        }),
      },
    );

    const tuneManagedEcsDeployment = new cr.AwsCustomResource(
      this,
      'TuneManagedEcsDeployment',
      {
        onCreate: {
          service: 'ECS',
          action: 'updateService',
          parameters: {
            cluster: 'default',
            service: expressService.attrServiceArn,
            deploymentConfiguration: {
              deploymentCircuitBreaker: {
                enable: true,
                rollback: true,
              },
               maximumPercent: deploymentMaximumPercent,
               minimumHealthyPercent: deploymentMinimumHealthyPercent,
            },
          },
          outputPaths: ['service.serviceArn'],
          physicalResourceId: cr.PhysicalResourceId.of(
            `ecs-deployment-${deploymentTuningVersion}`,
          ),
        },
        onUpdate: {
          service: 'ECS',
          action: 'updateService',
          parameters: {
            cluster: 'default',
            service: expressService.attrServiceArn,
            deploymentConfiguration: {
              deploymentCircuitBreaker: {
                enable: true,
                rollback: true,
              },
               maximumPercent: deploymentMaximumPercent,
               minimumHealthyPercent: deploymentMinimumHealthyPercent,
            },
          },
          outputPaths: ['service.serviceArn'],
          physicalResourceId: cr.PhysicalResourceId.of(
            `ecs-deployment-${deploymentTuningVersion}`,
          ),
        },
        policy: cr.AwsCustomResourcePolicy.fromSdkCalls({
          resources: cr.AwsCustomResourcePolicy.ANY_RESOURCE,
        }),
      },
    );

    tuneManagedTargetGroupHealthCheck.node.addDependency(expressService);
    tuneManagedTargetGroupDraining.node.addDependency(expressService);
    tuneManagedEcsDeployment.node.addDependency(expressService);
    tuneManagedEcsDeployment.node.addDependency(tuneManagedTargetGroupHealthCheck);
    tuneManagedEcsDeployment.node.addDependency(tuneManagedTargetGroupDraining);

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

    new cdk.CfnOutput(this, 'RequestImagesBucketName', {
      value: requestImagesBucket.bucketName,
      description: 'The private S3 bucket that stores request images',
    });

    new cdk.CfnOutput(this, 'RequestsTableName', {
      value: table.tableName,
      description: 'The DynamoDB table that stores recycling requests',
    });

    new cdk.CfnOutput(this, 'ExpressServiceArn', {
      value: expressService.attrServiceArn,
      description: 'The ARN of the ECS Express service',
    });
  }
}
