# TAMS Test Drive Playbook

A step-by-step guide to test driving the TAMS API using the command line.

## Prerequisites

Before you begin:

1. ✅ Infrastructure deployed (`terraform apply` completed)
2. ✅ Authenticated with GCP: `gcloud auth login`
3. ✅ Your email in `terraform/terraform.tfvars` `iap_users` list
4. ✅ `jq` installed (optional, for pretty JSON): `brew install jq` (macOS)

## Setup

### Get Your API Endpoint

```bash
cd terraform
export TAMS_API_URL=$(terraform output -raw tams_api_url)
echo "TAMS API: $TAMS_API_URL"
cd ..
```

### Create Authentication Helper

```bash
# Function to make authenticated API calls
tams_api() {
    local method=${1:-GET}
    local endpoint=$2
    local data=$3

    local token=$(gcloud auth print-identity-token)

    if [ -z "$data" ]; then
        curl -s -X "$method" \
            -H "Authorization: Bearer $token" \
            "$TAMS_API_URL$endpoint" | jq '.' 2>/dev/null || cat
    else
        curl -s -X "$method" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$TAMS_API_URL$endpoint" | jq '.' 2>/dev/null || cat
    fi
}
```

Add this to your `~/.bashrc` or `~/.zshrc` for permanent use, or just run it in your terminal for this session.

## Test Drive Workflow

### Step 1: Health Check

Verify the API is running:

```bash
tams_api GET /health
```

**Expected Output:**
```json
{
  "status": "healthy",
  "version": "v1.0",
  "timestamp": "2024-10-01T18:30:00.123456"
}
```

### Step 2: Create Your First Source

A Source represents a top-level media source (e.g., Camera, Microphone).

```bash
tams_api POST /sources '{
  "id": "camera-1",
  "label": "Studio Camera 1",
  "description": "Main studio camera feed"
}'
```

**Expected Output:**
```json
{
  "id": "camera-1",
  "label": "Studio Camera 1",
  "description": "Main studio camera feed",
  "tags": {},
  "created_at": "2024-10-01T18:30:00.123456",
  "updated_at": "2024-10-01T18:30:00.123456"
}
```

### Step 3: List All Sources

```bash
tams_api GET /sources
```

**Expected Output:**
```json
[
  {
    "id": "camera-1",
    "label": "Studio Camera 1",
    "description": "Main studio camera feed",
    "tags": {},
    "created_at": "2024-10-01T18:30:00.123456",
    "updated_at": "2024-10-01T18:30:00.123456"
  }
]
```

### Step 4: Create a Flow

A Flow represents a continuous stream of media within a source.

```bash
tams_api POST /flows '{
  "id": "video-flow-1",
  "source_id": "camera-1",
  "label": "Main Video Stream",
  "description": "High quality video feed",
  "format": "video/mp4",
  "codec": "h264"
}'
```

**Expected Output:**
```json
{
  "id": "video-flow-1",
  "source_id": "camera-1",
  "label": "Main Video Stream",
  "description": "High quality video feed",
  "format": "video/mp4",
  "codec": "h264",
  "tags": {},
  "timerange_start": null,
  "timerange_end": null,
  "created_at": "2024-10-01T18:31:00.123456",
  "updated_at": "2024-10-01T18:31:00.123456"
}
```

### Step 5: List Flows

```bash
# List all flows
tams_api GET /flows

# List flows for a specific source
tams_api GET "/flows?source_id=camera-1"
```

### Step 6: Upload a Segment

Segments are time-addressable chunks of media with precise timestamps.

**Create a test file:**
```bash
echo "Test media content" > test-segment.mp4
```

**Upload the segment:**
```bash
# Get auth token
TOKEN=$(gcloud auth print-identity-token)

# Upload with multipart form data
curl -X POST "$TAMS_API_URL/segments" \
  -H "Authorization: Bearer $TOKEN" \
  -F "id=segment-001" \
  -F "flow_id=video-flow-1" \
  -F "timerange_start=2024-10-01T10:00:00Z" \
  -F "timerange_end=2024-10-01T10:01:00Z" \
  -F "file=@test-segment.mp4" \
  | jq '.'
```

**Expected Output:**
```json
{
  "id": "segment-001",
  "flow_id": "video-flow-1",
  "timerange_start": "2024-10-01T10:00:00Z",
  "timerange_end": "2024-10-01T10:01:00Z",
  "duration": null,
  "storage_uri": "gs://smc-gcp-tams-testdrive-tams-media/flows/video-flow-1/segments/segment-001",
  "size_bytes": 19,
  "tags": {},
  "created_at": "2024-10-01T18:32:00.123456"
}
```

### Step 7: List Segments

```bash
# List all segments
tams_api GET /segments

# List segments for a specific flow
tams_api GET "/segments?flow_id=video-flow-1"
```

### Step 8: Get Segment Details

```bash
tams_api GET /segments/segment-001
```

### Step 9: Download a Segment

Get a signed URL to download the segment:

```bash
tams_api GET /segments/segment-001/download
```

**Expected Output:**
```json
{
  "url": "https://storage.googleapis.com/...",
  "expires_in": 3600
}
```

**Download the file:**
```bash
# Extract the URL and download
DOWNLOAD_URL=$(tams_api GET /segments/segment-001/download | jq -r '.url')
curl -o downloaded-segment.mp4 "$DOWNLOAD_URL"
```

### Step 10: Delete Resources

**Delete a segment:**
```bash
tams_api DELETE /segments/segment-001
```

**Delete a flow:**
```bash
tams_api DELETE /flows/video-flow-1
```

**Delete a source:**
```bash
tams_api DELETE /sources/camera-1
```

## Advanced Scenarios

### Scenario 1: Multi-Camera Setup

Create multiple sources and flows for a multi-camera production:

```bash
# Camera 1
tams_api POST /sources '{
  "id": "cam-1",
  "label": "Camera 1 - Wide Shot"
}'

tams_api POST /flows '{
  "id": "cam-1-video",
  "source_id": "cam-1",
  "label": "Video",
  "format": "video/mp4",
  "codec": "h264"
}'

# Camera 2
tams_api POST /sources '{
  "id": "cam-2",
  "label": "Camera 2 - Close Up"
}'

tams_api POST /flows '{
  "id": "cam-2-video",
  "source_id": "cam-2",
  "label": "Video",
  "format": "video/mp4",
  "codec": "h264"
}'

# Audio
tams_api POST /sources '{
  "id": "mic-1",
  "label": "Studio Microphone"
}'

tams_api POST /flows '{
  "id": "audio-main",
  "source_id": "mic-1",
  "label": "Main Audio",
  "format": "audio/aac",
  "codec": "aac"
}'
```

### Scenario 2: Time-Based Media Query

Upload segments with sequential timestamps:

```bash
# Segment 1: 10:00:00 - 10:01:00
curl -X POST "$TAMS_API_URL/segments" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -F "id=seg-001" \
  -F "flow_id=cam-1-video" \
  -F "timerange_start=2024-10-01T10:00:00Z" \
  -F "timerange_end=2024-10-01T10:01:00Z" \
  -F "file=@segment1.mp4"

# Segment 2: 10:01:00 - 10:02:00
curl -X POST "$TAMS_API_URL/segments" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -F "id=seg-002" \
  -F "flow_id=cam-1-video" \
  -F "timerange_start=2024-10-01T10:01:00Z" \
  -F "timerange_end=2024-10-01T10:02:00Z" \
  -F "file=@segment2.mp4"

# Segment 3: 10:02:00 - 10:03:00
curl -X POST "$TAMS_API_URL/segments" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -F "id=seg-003" \
  -F "flow_id=cam-1-video" \
  -F "timerange_start=2024-10-01T10:02:00Z" \
  -F "timerange_end=2024-10-01T10:03:00Z" \
  -F "file=@segment3.mp4"
```

### Scenario 3: Bulk Operations

Create multiple resources efficiently:

```bash
# Create multiple sources
for i in {1..5}; do
  tams_api POST /sources "{
    \"id\": \"source-$i\",
    \"label\": \"Source $i\",
    \"description\": \"Test source $i\"
  }"
done

# List all sources
tams_api GET /sources
```

## Helper Scripts

### Quick Test Script

Save this as `quick-test.sh`:

```bash
#!/bin/bash
set -e

cd terraform
export TAMS_API_URL=$(terraform output -raw tams_api_url)
cd ..

TOKEN=$(gcloud auth print-identity-token)

echo "Creating source..."
curl -s -X POST "$TAMS_API_URL/sources" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id":"test-source","label":"Test Source"}' | jq '.'

echo -e "\nCreating flow..."
curl -s -X POST "$TAMS_API_URL/flows" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id":"test-flow","source_id":"test-source","label":"Test Flow","format":"video/mp4"}' | jq '.'

echo -e "\nCreating test file..."
echo "test" > /tmp/test.mp4

echo -e "\nUploading segment..."
curl -s -X POST "$TAMS_API_URL/segments" \
  -H "Authorization: Bearer $TOKEN" \
  -F "id=test-seg" \
  -F "flow_id=test-flow" \
  -F "timerange_start=2024-10-01T10:00:00Z" \
  -F "timerange_end=2024-10-01T10:01:00Z" \
  -F "file=@/tmp/test.mp4" | jq '.'

echo -e "\nListing segments..."
curl -s -H "Authorization: Bearer $TOKEN" \
  "$TAMS_API_URL/segments" | jq '.'

echo -e "\nTest complete!"
```

### Cleanup Script

Save this as `cleanup-all.sh`:

```bash
#!/bin/bash
set -e

cd terraform
export TAMS_API_URL=$(terraform output -raw tams_api_url)
cd ..

TOKEN=$(gcloud auth print-identity-token)

echo "Deleting all segments..."
for seg in $(curl -s -H "Authorization: Bearer $TOKEN" "$TAMS_API_URL/segments" | jq -r '.[].id'); do
  echo "  Deleting segment: $seg"
  curl -s -X DELETE -H "Authorization: Bearer $TOKEN" "$TAMS_API_URL/segments/$seg"
done

echo "Deleting all flows..."
for flow in $(curl -s -H "Authorization: Bearer $TOKEN" "$TAMS_API_URL/flows" | jq -r '.[].id'); do
  echo "  Deleting flow: $flow"
  curl -s -X DELETE -H "Authorization: Bearer $TOKEN" "$TAMS_API_URL/flows/$flow"
done

echo "Deleting all sources..."
for source in $(curl -s -H "Authorization: Bearer $TOKEN" "$TAMS_API_URL/sources" | jq -r '.[].id'); do
  echo "  Deleting source: $source"
  curl -s -X DELETE -H "Authorization: Bearer $TOKEN" "$TAMS_API_URL/sources/$source"
done

echo "Cleanup complete!"
```

## Troubleshooting

### Authentication Issues

**Problem:** `401 Unauthorized`

**Solution:**
```bash
# Refresh your authentication
gcloud auth login
gcloud auth application-default login

# Verify you have a valid token
gcloud auth print-identity-token
```

### Can't Connect to API

**Problem:** Connection refused or timeout

**Solution:**
```bash
# Check Cloud Run service is running
gcloud run services describe tams-api --region=us-central1

# Check logs
gcloud run services logs read tams-api --region=us-central1 --limit=50
```

### Token Expired

**Problem:** `403 Forbidden` after some time

**Solution:**
```bash
# Identity tokens expire after 1 hour
# Get a fresh token
TOKEN=$(gcloud auth print-identity-token)
```

### Segment Upload Fails

**Problem:** Error uploading large files

**Solution:**
```bash
# Check file size
ls -lh your-file.mp4

# For large files, may need to increase Cloud Run timeout
# (configured in terraform/cloudrun-api.tf)
```

## API Reference Quick Guide

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check |
| `POST` | `/sources` | Create source |
| `GET` | `/sources` | List sources |
| `GET` | `/sources/{id}` | Get source |
| `DELETE` | `/sources/{id}` | Delete source |
| `POST` | `/flows` | Create flow |
| `GET` | `/flows` | List flows |
| `GET` | `/flows/{id}` | Get flow |
| `DELETE` | `/flows/{id}` | Delete flow |
| `POST` | `/segments` | Upload segment |
| `GET` | `/segments` | List segments |
| `GET` | `/segments/{id}` | Get segment |
| `GET` | `/segments/{id}/download` | Get download URL |
| `DELETE` | `/segments/{id}` | Delete segment |

## Next Steps

1. **Explore the Web UI**: `terraform output tams_frontend_url`
2. **Check the API Docs**: Interactive docs at `$TAMS_API_URL/docs`
3. **Review TAMS Spec**: [BBC TAMS GitHub](https://github.com/bbc/tams)
4. **Build Integration**: Use this API in your CNAP workflows

## Tips

- **Use jq**: Makes JSON output readable
- **Save tokens**: `export TOKEN=$(gcloud auth print-identity-token)`
- **Use variables**: Store URLs and IDs in variables
- **Script it**: Automate common workflows
- **Check logs**: `gcloud run services logs read tams-api --region=us-central1`

## Resources

- **TAMS Specification**: https://github.com/bbc/tams
- **API Documentation**: `$TAMS_API_URL/docs`
- **Project README**: `../README.md`
- **Terraform Docs**: `terraform-readme.md`
