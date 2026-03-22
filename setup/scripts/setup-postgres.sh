#!/bin/bash
set -euo pipefail

echo "=== Setting up PostgreSQL + pgvector ==="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../.env" 2>/dev/null || true

PG_USER="${POSTGRES_USER:-openclaw}"

# Wait for PostgreSQL to be healthy
echo "Waiting for PostgreSQL..."
until docker exec setup-postgres-1 pg_isready -U "$PG_USER" -h 127.0.0.1 2>/dev/null; do
  echo "  ...waiting"
  sleep 2
done
echo "PostgreSQL is ready."

# Create databases (ignore errors if they already exist)
echo "Creating databases..."
for db in memos surfsense ragflow; do
  docker exec setup-postgres-1 psql -U "$PG_USER" -c "CREATE DATABASE $db;" 2>/dev/null && \
    echo "  Created database: $db" || \
    echo "  Database already exists: $db"
done

# Enable pgvector on all databases
echo "Enabling pgvector..."
for db in openclaw memos surfsense ragflow; do
  docker exec setup-postgres-1 psql -U "$PG_USER" -d "$db" -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null && \
    echo "  pgvector enabled on: $db" || \
    echo "  pgvector already enabled on: $db"
done

echo ""
echo "PostgreSQL setup complete."
echo "  Databases: openclaw, memos, surfsense, ragflow"
echo "  Extension: pgvector enabled on all databases"
