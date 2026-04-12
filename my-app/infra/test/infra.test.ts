import * as cdk from 'aws-cdk-lib';
import { Match, Template } from 'aws-cdk-lib/assertions';

import { InfraStack } from '../lib/infra-stack';

test('request images bucket allows browser image reads through CORS', () => {
  const app = new cdk.App();
  const stack = new InfraStack(app, 'MyTestStack');
  const template = Template.fromStack(stack);

  template.hasResourceProperties('AWS::S3::Bucket', {
    BucketName: 'panta-go-request-images',
    CorsConfiguration: {
      CorsRules: Match.arrayWith([
        Match.objectLike({
          AllowedMethods: ['GET', 'HEAD'],
          AllowedOrigins: ['*'],
          AllowedHeaders: ['*'],
          MaxAge: 3000,
        }),
      ]),
    },
  });
});

test('requests table exposes ownership and access query indexes', () => {
  const app = new cdk.App();
  const stack = new InfraStack(app, 'MyTestStack');
  const template = Template.fromStack(stack);

  template.hasResourceProperties('AWS::DynamoDB::Table', {
    TableName: 'panta-go-requests',
    GlobalSecondaryIndexes: Match.arrayWith([
      Match.objectLike({
        IndexName: 'requests-by-creator',
        KeySchema: [
          { AttributeName: 'creatorId', KeyType: 'HASH' },
          { AttributeName: 'scheduledFrom', KeyType: 'RANGE' },
        ],
      }),
      Match.objectLike({
        IndexName: 'requests-by-status',
        KeySchema: [
          { AttributeName: 'status', KeyType: 'HASH' },
          { AttributeName: 'scheduledFrom', KeyType: 'RANGE' },
        ],
      }),
      Match.objectLike({
        IndexName: 'requests-by-helper',
        KeySchema: [
          { AttributeName: 'helperId', KeyType: 'HASH' },
          { AttributeName: 'scheduledFrom', KeyType: 'RANGE' },
        ],
      }),
    ]),
  });
});

test('backend service uses safer deployment defaults and structured logging retention', () => {
  const app = new cdk.App();
  const stack = new InfraStack(app, 'MyTestStack');
  const template = Template.fromStack(stack);

  template.hasResourceProperties('AWS::Logs::LogGroup', {
    RetentionInDays: 14,
  });

  template.hasResourceProperties('AWS::ECS::ExpressGatewayService', {
    HealthCheckPath: '/health',
    ScalingTarget: {
      MaxTaskCount: 1,
      MinTaskCount: 1,
    },
    PrimaryContainer: Match.objectLike({
      AwsLogsConfiguration: Match.objectLike({
        LogStreamPrefix: 'PantaGoBackendService',
      }),
    }),
  });

  const customResources = template.findResources('Custom::AWS');
  const deploymentResourceEntry = Object.entries(customResources).find(([logicalId]) =>
    logicalId.includes('TuneManagedEcsDeployment'),
  );

  expect(deploymentResourceEntry).toBeDefined();

  const serializedDeploymentConfig = JSON.stringify(deploymentResourceEntry?.[1]);
  expect(serializedDeploymentConfig).toContain('\\"minimumHealthyPercent\\":100');
  expect(serializedDeploymentConfig).toContain('\\"maximumPercent\\":200');
  expect(serializedDeploymentConfig).toContain('\\"rollback\\":true');
});
