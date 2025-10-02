#!/bin/bash
# TAMS API Testing Helper Script

set -e

# Get API URL from terraform
cd terraform
API_URL=$(terraform output -raw tams_api_url 2>/dev/null || echo "")
cd ..

if [ -z "$API_URL" ]; then
    echo "Error: Could not get API URL. Run 'terraform apply' first."
    exit 1
fi

echo "TAMS API URL: $API_URL"
echo ""

# Get auth token
TOKEN=$(gcloud auth print-identity-token)

# Function to make authenticated API calls
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3

    if [ -z "$data" ]; then
        curl -s -X "$method" \
            -H "Authorization: Bearer $TOKEN" \
            "$API_URL$endpoint" | jq '.' 2>/dev/null || cat
    else
        curl -s -X "$method" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$API_URL$endpoint" | jq '.' 2>/dev/null || cat
    fi
}

# Show menu
echo "TAMS API Test Commands:"
echo ""
echo "1. Health Check"
echo "2. List Sources"
echo "3. Create Test Source"
echo "4. List Flows"
echo "5. Create Test Flow"
echo "6. List Segments"
echo "7. Get API URL"
echo "8. Custom curl command"
echo ""

read -p "Select option (1-8): " option

case $option in
    1)
        echo "=== Health Check ==="
        api_call GET "/health"
        ;;
    2)
        echo "=== List Sources ==="
        api_call GET "/sources"
        ;;
    3)
        echo "=== Create Test Source ==="
        api_call POST "/sources" '{
            "id": "test-source-'$(date +%s)'",
            "label": "Test Source",
            "description": "Created via test script"
        }'
        ;;
    4)
        echo "=== List Flows ==="
        api_call GET "/flows"
        ;;
    5)
        read -p "Enter source ID: " source_id
        echo "=== Create Test Flow ==="
        api_call POST "/flows" '{
            "id": "test-flow-'$(date +%s)'",
            "source_id": "'$source_id'",
            "label": "Test Flow",
            "format": "video/mp4",
            "codec": "h264"
        }'
        ;;
    6)
        echo "=== List Segments ==="
        api_call GET "/segments"
        ;;
    7)
        echo "=== API URL ==="
        echo "$API_URL"
        echo ""
        echo "Auth Token (valid for 1 hour):"
        echo "$TOKEN"
        ;;
    8)
        echo "Example: GET /sources"
        read -p "Enter endpoint (e.g., /sources): " endpoint
        api_call GET "$endpoint"
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "Done!"
