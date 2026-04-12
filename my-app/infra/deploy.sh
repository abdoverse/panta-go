#!/bin/bash
set -e # Exit on error

echo "Deploying Panta Go Infrastructure..."

# Navigate to script directory
cd "$(dirname "$0")"

# Install dependencies if node_modules is missing
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Bootstrap is temporarily disabled; re-enable if the toolkit stack needs to be refreshed.
# echo "Bootstrapping CDK..."
# npx cdk bootstrap

# Deploy
echo "Deploying Stack..."
npx cdk deploy --require-approval never

echo "Syncing mobile config from stack outputs..."
node scripts/sync-mobile-config.js

echo "Deployment complete!"
