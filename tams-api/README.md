# TAMS API Server

Simplified implementation of the BBC TAMS (Time Addressable Media Store) API for GCP.

## Features

- **Sources**: Manage media sources
- **Flows**: Manage media flows within sources
- **Segments**: Upload, store, and retrieve time-based media segments
- **Storage**: GCS-backed media storage
- **Database**: PostgreSQL metadata storage

## API Endpoints

### Health
- `GET /` - Root health check
- `GET /health` - Detailed health check

### Sources
- `POST /sources` - Create a new source
- `GET /sources` - List all sources
- `GET /sources/{source_id}` - Get specific source
- `DELETE /sources/{source_id}` - Delete a source

### Flows
- `POST /flows` - Create a new flow
- `GET /flows?source_id={id}` - List flows (optionally filtered by source)
- `GET /flows/{flow_id}` - Get specific flow
- `DELETE /flows/{flow_id}` - Delete a flow

### Segments
- `POST /segments` - Create segment with media upload
- `GET /segments?flow_id={id}` - List segments (optionally filtered by flow)
- `GET /segments/{segment_id}` - Get segment metadata
- `GET /segments/{segment_id}/download` - Get download URL
- `DELETE /segments/{segment_id}` - Delete a segment

## Environment Variables

- `DB_HOST` - Database host (default: localhost)
- `DB_PORT` - Database port (default: 5432)
- `DB_NAME` - Database name (default: tams)
- `DB_USER` - Database user (default: tams)
- `DB_PASSWORD` - Database password
- `INSTANCE_CONNECTION_NAME` - Cloud SQL connection name (for GCP)
- `GCS_BUCKET` - GCS bucket name for media storage
- `PORT` - Server port (default: 8080)
- `HOST` - Server host (default: 0.0.0.0)

## Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export DB_PASSWORD=your_password
export GCS_BUCKET=your-bucket-name

# Run the server
python -m uvicorn app.main:app --reload --port 8080
```

## Docker Build

```bash
# Build image
docker build -t tams-api .

# Run container
docker run -p 8080:8080 \
  -e DB_PASSWORD=password \
  -e GCS_BUCKET=bucket-name \
  tams-api
```
