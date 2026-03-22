#!/bin/bash
set -euo pipefail

echo "=== Setting up PostgreSQL + pgvector ==="

source "$(dirname "$0")/../.env" 2>/dev/null || true

# Wait for PostgreSQL to be healthy
echo "Waiting for PostgreSQL..."
until docker compose -f setup/docker-compose.nova.yml exec -T postgres pg_isready -U "${POSTGRES_USER:-openclaw}" 2>/dev/null; do
  sleep 2
done

echo "Creating databases..."
docker compose -f setup/docker-compose.nova.yml exec -T postgres psql -U "${POSTGRES_USER:-openclaw}" <<SQL
-- Create separate databases for each service
CREATE DATABASE memos;
CREATE DATABASE surfsense;
CREATE DATABASE ragflow;

-- Enable pgvector on all databases
\c openclaw
CREATE EXTENSION IF NOT EXISTS vector;
\c memos
CREATE EXTENSION IF NOT EXISTS vector;
\c surfsense
CREATE EXTENSION IF NOT EXISTS vector;
\c ragflow
CREATE EXTENSION IF NOT EXISTS vector;
SQL

echo "PostgreSQL setup complete."
echo "  Databases: openclaw, memos, surfsense, ragflow"
echo "  Extension: pgvector enabled on all databases"
