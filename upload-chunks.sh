#!/bin/bash
set -e

# TAMS Upload Script
# Uploads chunked video files to TAMS API

# Configuration
CHUNKS_DIR="archive/chunked-archive"
TAMS_API_URL="${TAMS_API_URL:-http://localhost:8080}"  # Override with env var if needed
SOURCE_ID="donington-1993"
SOURCE_LABEL="1993 F1 Race at Donington"
SOURCE_DESCRIPTION="1993 Formula 1 European Grand Prix at Donington Park"
FLOW_ID="donington-1993-main"
FLOW_LABEL="Main Video Stream"
FLOW_FORMAT="video/x-matroska"
FLOW_CODEC="h264"
BASE_DATE="1993-06-06T00:00:00Z"  # Reference timestamp for chunks

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== TAMS Upload Script ===${NC}"
echo ""

# Check if chunks directory exists
if [ ! -d "$CHUNKS_DIR" ]; then
    echo -e "${RED}Error: Chunks directory not found: $CHUNKS_DIR${NC}"
    echo "Run ./chunk-video.sh first to create chunks"
    exit 1
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed${NC}"
    exit 1
fi

# Get TAMS API URL from terraform output if not set
if [ "$TAMS_API_URL" = "http://localhost:8080" ]; then
    if [ -f "terraform/terraform.tfstate" ]; then
        TAMS_API_URL=$(grep -A 2 '"tams_api_url"' terraform/terraform.tfstate | grep '"value"' | sed 's/.*"value": "\(.*\)".*/\1/' | tr -d '\n' || echo "")
        if [ -n "$TAMS_API_URL" ]; then
            echo -e "${YELLOW}Using TAMS API URL from terraform: $TAMS_API_URL${NC}"
        fi
    fi
fi

echo "TAMS API URL: $TAMS_API_URL"
echo ""

# Check if TAMS API is reachable
echo -e "${BLUE}Checking TAMS API health...${NC}"
if ! curl -sf "${TAMS_API_URL}/health" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot reach TAMS API at $TAMS_API_URL${NC}"
    echo "Make sure the TAMS API is running or set TAMS_API_URL environment variable"
    exit 1
fi
echo -e "${GREEN}✓ API is reachable${NC}"
echo ""

# Step 1: Create Source
echo -e "${BLUE}Step 1: Creating source...${NC}"
SOURCE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${TAMS_API_URL}/sources" \
    -H "Content-Type: application/json" \
    -d "{
        \"id\": \"${SOURCE_ID}\",
        \"label\": \"${SOURCE_LABEL}\",
        \"description\": \"${SOURCE_DESCRIPTION}\"
    }")

HTTP_CODE=$(echo "$SOURCE_RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$SOURCE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}✓ Source created: ${SOURCE_ID}${NC}"
elif [ "$HTTP_CODE" = "409" ]; then
    echo -e "${YELLOW}⚠ Source already exists: ${SOURCE_ID}${NC}"
else
    echo -e "${RED}✗ Failed to create source (HTTP $HTTP_CODE)${NC}"
    echo "$RESPONSE_BODY"
    exit 1
fi
echo ""

# Step 2: Create Flow
echo -e "${BLUE}Step 2: Creating flow...${NC}"
FLOW_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${TAMS_API_URL}/flows" \
    -H "Content-Type: application/json" \
    -d "{
        \"id\": \"${FLOW_ID}\",
        \"source_id\": \"${SOURCE_ID}\",
        \"label\": \"${FLOW_LABEL}\",
        \"format\": \"${FLOW_FORMAT}\",
        \"codec\": \"${FLOW_CODEC}\"
    }")

HTTP_CODE=$(echo "$FLOW_RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$FLOW_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}✓ Flow created: ${FLOW_ID}${NC}"
elif [ "$HTTP_CODE" = "409" ]; then
    echo -e "${YELLOW}⚠ Flow already exists: ${FLOW_ID}${NC}"
else
    echo -e "${RED}✗ Failed to create flow (HTTP $HTTP_CODE)${NC}"
    echo "$RESPONSE_BODY"
    exit 1
fi
echo ""

# Step 3: Upload Segments
echo -e "${BLUE}Step 3: Uploading segments...${NC}"
echo ""

CHUNK_COUNT=0
SUCCESS_COUNT=0
FAILED_COUNT=0

# Function to calculate ISO 8601 timestamp from chunk number
calculate_timestamp() {
    local chunk_num=$1
    local minutes=$(( (chunk_num - 1) * 5 ))

    # Use Python to calculate proper ISO 8601 timestamp
    python3 -c "
from datetime import datetime, timedelta
base = datetime.fromisoformat('${BASE_DATE}'.replace('Z', '+00:00'))
offset = timedelta(minutes=${minutes})
print((base + offset).isoformat().replace('+00:00', 'Z'))
"
}

for chunk_file in ${CHUNKS_DIR}/1993-donington-chunk-*.mkv; do
    if [ ! -f "$chunk_file" ]; then
        continue
    fi

    CHUNK_COUNT=$((CHUNK_COUNT + 1))
    CHUNK_NAME=$(basename "$chunk_file" .mkv)

    # Extract chunk number (e.g., 001 from 1993-donington-chunk-001.mkv)
    CHUNK_NUM=$(echo "$CHUNK_NAME" | grep -o '[0-9]\{3\}$')
    SEGMENT_ID="${SOURCE_ID}-segment-${CHUNK_NUM}"

    # Calculate timestamps
    TIMERANGE_START=$(calculate_timestamp $((10#$CHUNK_NUM)))
    TIMERANGE_END=$(calculate_timestamp $((10#$CHUNK_NUM + 1)))

    echo -e "${BLUE}[$CHUNK_COUNT] Uploading: $CHUNK_NAME${NC}"
    echo "    Segment ID: $SEGMENT_ID"
    echo "    Timerange: $TIMERANGE_START → $TIMERANGE_END"

    # Step 1: Request signed upload URL
    URL_REQUEST=$(cat <<EOF
{
    "flow_id": "${FLOW_ID}",
    "segment_id": "${SEGMENT_ID}",
    "content_type": "video/x-matroska"
}
EOF
)

    URL_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${TAMS_API_URL}/segments/upload-url" \
        -H "Content-Type: application/json" \
        -d "${URL_REQUEST}")

    HTTP_CODE=$(echo "$URL_RESPONSE" | tail -n 1)
    RESPONSE_BODY=$(echo "$URL_RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" != "200" ]; then
        echo -e "    ${RED}✗ Failed to get upload URL (HTTP $HTTP_CODE)${NC}"
        echo "    $RESPONSE_BODY"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        continue
    fi

    # Extract signed URL and GCS URI from response
    UPLOAD_URL=$(echo "$RESPONSE_BODY" | python3 -c "import sys, json; print(json.load(sys.stdin)['upload_url'])" 2>/dev/null)
    GCS_URI=$(echo "$RESPONSE_BODY" | python3 -c "import sys, json; print(json.load(sys.stdin)['gcs_uri'])" 2>/dev/null)

    if [ -z "$UPLOAD_URL" ]; then
        echo -e "    ${RED}✗ Failed to parse upload URL${NC}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        continue
    fi

    # Step 2: Upload file directly to GCS using signed URL
    echo "    Uploading to GCS..."
    GCS_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "${UPLOAD_URL}" \
        -H "Content-Type: video/x-matroska" \
        --upload-file "${chunk_file}")

    HTTP_CODE=$(echo "$GCS_RESPONSE" | tail -n 1)

    if [ "$HTTP_CODE" != "200" ]; then
        echo -e "    ${RED}✗ GCS upload failed (HTTP $HTTP_CODE)${NC}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        continue
    fi

    # Step 3: Create segment metadata in TAMS
    SEGMENT_JSON=$(cat <<EOF
{
    "id": "${SEGMENT_ID}",
    "flow_id": "${FLOW_ID}",
    "timerange_start": "${TIMERANGE_START}",
    "timerange_end": "${TIMERANGE_END}",
    "storage_uri": "${GCS_URI}"
}
EOF
)

    CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${TAMS_API_URL}/segments/direct" \
        -H "Content-Type: application/json" \
        -d "${SEGMENT_JSON}")

    HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -n 1)
    RESPONSE_BODY=$(echo "$CREATE_RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" = "201" ]; then
        echo -e "    ${GREEN}✓ Uploaded successfully${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    elif [ "$HTTP_CODE" = "409" ]; then
        echo -e "    ${YELLOW}⚠ Segment already exists${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "    ${RED}✗ Metadata creation failed (HTTP $HTTP_CODE)${NC}"
        echo "    $RESPONSE_BODY"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
    echo ""
done

# Summary
echo -e "${BLUE}=== Upload Summary ===${NC}"
echo -e "Total chunks processed: $CHUNK_COUNT"
echo -e "${GREEN}Successful uploads: $SUCCESS_COUNT${NC}"
if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "${RED}Failed uploads: $FAILED_COUNT${NC}"
fi
echo ""
echo -e "${GREEN}✓ Upload complete!${NC}"
echo ""
echo -e "${BLUE}View your data:${NC}"
echo "  Source: ${TAMS_API_URL}/sources/${SOURCE_ID}"
echo "  Flow: ${TAMS_API_URL}/flows/${FLOW_ID}"
echo "  Segments: ${TAMS_API_URL}/segments?flow_id=${FLOW_ID}"
