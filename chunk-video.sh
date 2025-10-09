#!/bin/bash
set -e

# Video Chunking Script for TAMS
# Splits a video into 5-minute chunks using ffmpeg

# Configuration
INPUT_VIDEO="archive/1993-donington.mkv"
OUTPUT_DIR="archive/chunked-archive"
CHUNK_DURATION=300  # 5 minutes in seconds
OUTPUT_PATTERN="${OUTPUT_DIR}/1993-donington-chunk-%03d.mkv"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Video Chunking Script ===${NC}"
echo ""

# Check if input file exists
if [ ! -f "$INPUT_VIDEO" ]; then
    echo "Error: Input video not found: $INPUT_VIDEO"
    exit 1
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed"
    echo "Install with: brew install ffmpeg"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Get video information
echo -e "${BLUE}Video Information:${NC}"
echo "Input: $INPUT_VIDEO"
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT_VIDEO" 2>/dev/null)
DURATION_MIN=$(echo "$DURATION" | awk '{printf "%.2f", $1/60}')
ESTIMATED_CHUNKS=$(echo "$DURATION $CHUNK_DURATION" | awk '{printf "%d", ($1/$2)+1}')
echo "Duration: ${DURATION_MIN} minutes"
echo "Chunk size: $(($CHUNK_DURATION / 60)) minutes"
echo "Estimated chunks: ~${ESTIMATED_CHUNKS}"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Confirm before proceeding
read -p "Proceed with chunking? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo -e "${BLUE}Chunking video...${NC}"
echo ""

# Use ffmpeg to chunk the video
# -i: input file
# -c copy: copy streams without re-encoding (fast and lossless)
# -f segment: use segment muxer
# -segment_time: duration of each chunk in seconds
# -reset_timestamps 1: reset timestamps for each chunk
# -map 0: copy all streams (video, audio, subtitles)
ffmpeg -i "$INPUT_VIDEO" \
    -c copy \
    -f segment \
    -segment_time $CHUNK_DURATION \
    -reset_timestamps 1 \
    -map 0 \
    "$OUTPUT_PATTERN"

echo ""
echo -e "${GREEN}✓ Chunking complete!${NC}"
echo ""

# List the created chunks with their durations
echo -e "${BLUE}Created chunks:${NC}"
CHUNK_COUNT=0
TOTAL_SIZE=0

for chunk in ${OUTPUT_DIR}/1993-donington-chunk-*.mkv; do
    if [ -f "$chunk" ]; then
        CHUNK_COUNT=$((CHUNK_COUNT + 1))
        SIZE=$(ls -lh "$chunk" | awk '{print $5}')
        SIZE_BYTES=$(stat -f%z "$chunk" 2>/dev/null || stat -c%s "$chunk" 2>/dev/null)
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE_BYTES))
        CHUNK_DURATION_SEC=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$chunk" 2>/dev/null)
        CHUNK_DURATION_MIN=$(echo "$CHUNK_DURATION_SEC" | awk '{printf "%.2f", $1/60}')
        echo "  $(basename "$chunk"): ${SIZE} (${CHUNK_DURATION_MIN} min)"
    fi
done

TOTAL_SIZE_MB=$(echo "$TOTAL_SIZE" | awk '{printf "%.2f MB", $1/1024/1024}')

echo ""
echo -e "${GREEN}Summary:${NC}"
echo "  Total chunks created: $CHUNK_COUNT"
echo "  Total size: $TOTAL_SIZE_MB"
echo "  Output directory: $OUTPUT_DIR"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Review the chunks in: $OUTPUT_DIR"
echo "  2. Upload chunks to TAMS using the frontend"
echo "  3. Each chunk represents a 5-minute time-addressable segment"
