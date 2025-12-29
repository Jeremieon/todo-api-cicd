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

# Backup current database state (for rollback)
echo "💾 Creating database backup..."
BACKUP_FILE="backup_${ENVIRONMENT}_$(date +%Y%m%d_%H%M%S).sql"
docker exec todo-db-${ENVIRONMENT} pg_dump -U postgres tododb > $BACKUP_FILE 2>/dev/null || echo "⚠️  No existing database to backup"

# Pull latest images
echo "📦 Pulling latest images..."
docker-compose --env-file $ENV_FILE -p todo-$ENVIRONMENT pull || true

# Build new image
echo "🏗️  Building new image..."
docker-compose --env-file $ENV_FILE -p todo-$ENVIRONMENT build

# Start database (if not running)
echo "🗄️  Ensuring database is running..."
docker-compose --env-file $ENV_FILE -p todo-$ENVIRONMENT up -d db

# Wait for database
echo "⏳ Waiting for database to be ready..."
sleep 10

# Database is ready, now stop old app container
echo "⏸️  Stopping old application..."
docker-compose --env-file $ENV_FILE -p todo-$ENVIRONMENT stop app || true

# Start new app (migrations will run automatically via CMD in Dockerfile)
echo "🚀 Starting new application (migrations will run)..."
docker-compose --env-file $ENV_FILE -p todo-$ENVIRONMENT up -d app

# Wait for app to start
echo "⏳ Waiting for application to start..."
sleep 15

# Health check
echo "🏥 Running health check..."
MAX_RETRIES=20
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f http://localhost:$APP_PORT/health > /dev/null 2>&1; then
        echo "✅ Health check passed!"
        
        # Remove old containers
        docker-compose --env-file $ENV_FILE -p todo-$ENVIRONMENT rm -f || true
        
        # Remove old backup (deployment successful)
        rm -f $BACKUP_FILE || true
        
        echo "🎉 Deployment successful!"
        echo "🔗 Application: http://localhost:$APP_PORT"
        echo "🔗 API Docs: http://localhost:$APP_PORT/docs"
        exit 0
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "⏳ Health check failed, retry $RETRY_COUNT/$MAX_RETRIES..."
    sleep 5
done

# Health check failed - rollback!
echo "❌ Health check failed after $MAX_RETRIES attempts"
echo "📋 Application logs:"
docker-compose --env-file $ENV_FILE -p todo-$ENVIRONMENT logs --tail=100 app

echo "🔄 Rolling back database and application..."

# Stop failed containers
docker-compose --env-file $ENV_FILE -p todo-$ENVIRONMENT down

# Restore database from backup if it exists
if [ -f "$BACKUP_FILE" ]; then
    echo "💾 Restoring database from backup..."
    docker-compose --env-file $ENV_FILE -p todo-$ENVIRONMENT up -d db
    sleep 10
    cat $BACKUP_FILE | docker exec -i todo-db-${ENVIRONMENT} psql -U postgres tododb
    echo "✅ Database restored"
fi

# Start old version
docker-compose --env-file $ENV_FILE -p todo-$ENVIRONMENT up -d

echo "❌ Deployment failed and rolled back!"
exit 1