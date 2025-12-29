#!/bin/bash
set -e

echo "🔄 Running database migrations..."

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
for i in {1..30}; do
    if pg_isready -h db -U postgres > /dev/null 2>&1; then
        echo "✅ Database is ready!"
        break
    fi
    echo "⏳ Attempt $i/30: Database not ready, waiting..."
    sleep 2
done

# Run migrations
echo "📦 Applying migrations..."
alembic upgrade head

if [ $? -eq 0 ]; then
    echo "✅ Migrations completed successfully!"
    exit 0
else
    echo "❌ Migration failed!"
    exit 1
fi