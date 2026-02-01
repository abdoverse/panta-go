import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as path from 'path';
import * as cognito from 'aws-cdk-lib/aws-cognito';

export class InfraStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create DynamoDB Table
    const table = new dynamodb.Table(this, 'PantaRequestsTable', {
      partitionKey: { name: 'id', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY, // For dev/demo only
    });

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

    // ========================================================================
    // LAMBDA BACKEND (FASTER DEPLOYS)
    // ========================================================================

    const backendFunction = new lambda.Function(this, 'PantaGoBackend', {
      runtime: lambda.Runtime.PROVIDED_AL2023,
      handler: 'bootstrap', // Go on AL2/AL2023 expects 'bootstrap' executable
      code: lambda.Code.fromAsset(path.join(__dirname, '../../backend'), {
        bundling: {
          image: cdk.DockerImage.fromRegistry('golang:1.22'), // Use specific modern Go image
          user: "root",
          command: [
            'bash', '-c',
            'go mod tidy && GOOS=linux GOARCH=amd64 go build -o /asset-output/bootstrap ./cmd/api'
          ],
        },
      }),
      memorySize: 128,
      timeout: cdk.Duration.seconds(30),
      environment: {
        TABLE_NAME: table.tableName,
        AWS_REGION: this.region,
        COGNITO_USER_POOL_ID: userPool.userPoolId,
        COGNITO_CLIENT_ID: userPoolClient.userPoolClientId,
      },
    });

    // Grant DynamoDB permissions
    table.grantReadWriteData(backendFunction);

    // Add Function URL (Public HTTP Endpoint)
    const functionUrl = backendFunction.addFunctionUrl({
      authType: lambda.FunctionUrlAuthType.NONE,
      cors: {
        allowedOrigins: ['*'],
        allowedMethods: [lambda.HttpMethod.ALL],
        allowedHeaders: ['*'],
      },
    });

    // Output Cognito Details for Mobile App
    new cdk.CfnOutput(this, 'UserPoolId', {
      value: userPool.userPoolId,
      description: 'Cognito User Pool ID',
    });

    new cdk.CfnOutput(this, 'UserPoolClientId', {
      value: userPoolClient.userPoolClientId,
      description: 'Cognito User Pool Client ID',
    });

    // Output the Service URL
    new cdk.CfnOutput(this, 'ServiceUrl', {
      value: functionUrl.url,
      description: 'The URL of the Lambda Backend',
      exportName: 'PantaGoBackendServiceUrl',
    });
  }
}
