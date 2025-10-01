# TAMS Frontend

Simple web interface for interacting with the TAMS API to tag timestamps and manage media segments.

## Features

- **Sources Management**: Create and view media sources
- **Flows Management**: Create and manage media flows
- **Segments Management**: Upload time-addressable media segments
- **Timestamp Helper**: Built-in tool to generate ISO 8601 timestamps

## Environment Variables

- `TAMS_API_URL` - TAMS API endpoint (default: http://localhost:8080)
- `PORT` - Server port (default: 8090)

## Local Development

```bash
# Install dependencies
go mod download

# Run the server
TAMS_API_URL=http://localhost:8080 go run main.go
```

## Docker Build

```bash
# Build image
docker build -t tams-frontend .

# Run container
docker run -p 8090:8090 \
  -e TAMS_API_URL=http://tams-api:8080 \
  tams-frontend
```

## Usage

1. Navigate to the frontend URL
2. Create a Source (e.g., "Camera 1")
3. Create a Flow within that source (e.g., "Video Stream")
4. Upload media segments with timestamp ranges
5. View all segments with their time-addressable metadata
