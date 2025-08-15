#!/bin/bash

# Get Node.js major version
NODE_VERSION=$(node -v | cut -d'.' -f1 | sed 's/v//')

echo "Detected Node.js version: $NODE_VERSION"

# Use legacy provider for Node 20+ due to stricter OpenSSL changes
if [ "$NODE_VERSION" -ge 20 ]; then
    echo "Using legacy OpenSSL provider for Node.js $NODE_VERSION"
    npm run build:legacy
else
    echo "Using standard build for Node.js $NODE_VERSION"
    npm run build
fi
