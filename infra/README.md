# Welcome to your CDK TypeScript project

This is a blank project for CDK development with TypeScript.

The `cdk.json` file tells the CDK Toolkit how to execute your app.

## Useful commands

* `npm run build`   compile typescript to js
* `npm run watch`   watch for changes and compile
* `npm run test`    perform the jest unit tests
* `npx cdk deploy`  deploy this stack to your default AWS account/region
* `npx cdk diff`    compare deployed stack with current state
* `npx cdk synth`   emits the synthesized CloudFormation template

## ⚠️ Production Readiness Requirements

The current ECS Express Mode deployment settings are optimized for **test deployment speed**, not safe production rollouts. They are intentionally aggressive and may allow dropped connections, brief downtime, and old tasks to stop before replacements are fully healthy.

Before treating this service as production-ready, revisit the deployment-speed tuning and restore safer rollout behavior. This includes reviewing the target group **deregistration delay**, load balancer **health check interval and thresholds**, and ECS **deployment percentages** so future deployments support safe, zero-downtime releases.
