#!/bin/bash
set -e

ENVIRONMENT=$1
VERSION=$2

echo "🚀 Starting deployment for $ENVIRONMENT environment..."

# Set environment-specific variables
if [ "$ENVIRONMENT" = "staging" ]; then
    export APP_PORT=8001
    export DB_PORT=5433
    ENV_FILE=".env.staging"
elif [ "$ENVIRONMENT" = "production" ]; then
    export APP_PORT=8000
    export DB_PORT=5432
    ENV_FILE=".env.production"
else
    echo "❌ Invalid environment: $ENVIRONMENT"
    exit 1
fi

export APP_VERSION=$VERSION

echo "📋 Configuration:"
echo "   Environment: $ENVIRONMENT"
echo "   Version: $VERSION"
echo "   App Port: $APP_PORT"
echo "   DB Port: $DB_PORT"

# Stop existing services
echo "⏸️  Stopping existing services..."
docker compose --env-file $ENV_FILE -p todo-$ENVIRONMENT down || true

#Login to registry
#echo "🔐 Logging into Docker registry..."
#echo $DOCKER_TOKEN | docker login -u $DOCKER_USERNAME --password-stdin


# Pull latest images
echo "📦 Pulling latest images..."
docker compose --env-file $ENV_FILE -p todo-$ENVIRONMENT pull || true

# Build and start services
echo "🏗️  Building and starting services..."
docker compose --env-file $ENV_FILE -p todo-$ENVIRONMENT up -d --build

# Wait for services to be ready
echo "⏳ Waiting for services to be healthy..."
sleep 10

# Health check
echo "🏥 Running health check..."
MAX_RETRIES=15
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f http://localhost:$APP_PORT/health > /dev/null 2>&1; then
        echo "✅ Health check passed!"
        echo "🎉 Deployment successful!"
        echo "🔗 Application: http://localhost:$APP_PORT"
        echo "🔗 API Docs: http://localhost:$APP_PORT/docs"
        exit 0
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "⏳ Health check failed, retry $RETRY_COUNT/$MAX_RETRIES..."
    sleep 5
done

# Health check failed - show logs and rollback
echo "❌ Health check failed after $MAX_RETRIES attempts"
echo "📋 Application logs:"
docker compose --env-file $ENV_FILE -p todo-$ENVIRONMENT logs --tail=50 app

echo "🔄 Rolling back..."
docker compose --env-file $ENV_FILE -p todo-$ENVIRONMENT down

echo "❌ Deployment failed!"
exit 1