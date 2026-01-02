#!/bin/bash
# Deploy a single page to WordPress
# Usage: ./deploy-page.sh <content-file> <wp-url> <username> <app-password>

set -e

CONTENT_FILE="$1"
WP_URL="$2"
WP_USERNAME="$3"
WP_APP_PASSWORD="$4"

if [[ -z "$CONTENT_FILE" ]] || [[ -z "$WP_URL" ]] || [[ -z "$WP_USERNAME" ]] || [[ -z "$WP_APP_PASSWORD" ]]; then
    echo "Usage: $0 <content-file> <wp-url> <username> <app-password>"
    exit 1
fi

# Extract page name from filename
BASENAME=$(basename "$CONTENT_FILE" .txt)
META_FILE="meta/${BASENAME}.json"

if [[ ! -f "$META_FILE" ]]; then
    echo "Error: Meta file not found: $META_FILE"
    exit 1
fi

if [[ ! -f "$CONTENT_FILE" ]]; then
    echo "Error: Content file not found: $CONTENT_FILE"
    exit 1
fi

# Read page ID from meta file
PAGE_ID=$(jq -r '.page_id' "$META_FILE")
PAGE_TITLE=$(jq -r '.title' "$META_FILE")

if [[ -z "$PAGE_ID" ]] || [[ "$PAGE_ID" == "null" ]]; then
    echo "Error: No page_id found in $META_FILE"
    exit 1
fi

echo "Deploying: $PAGE_TITLE (ID: $PAGE_ID)"
echo "Content file: $CONTENT_FILE ($(wc -c < "$CONTENT_FILE") bytes)"
echo "Target: $WP_URL"

# Build JSON payload using jq --rawfile to handle large content
# Use a temporary file to avoid "Argument list too long" errors
TEMP_PAYLOAD=$(mktemp)
trap "rm -f $TEMP_PAYLOAD" EXIT

jq -n \
    --rawfile content "$CONTENT_FILE" \
    '{
        content: $content,
        meta: {
            "_aviaLayoutBuilderCleanData": $content,
            "_aviaLayoutBuilder_active": "active"
        }
    }' > "$TEMP_PAYLOAD"

# Make the API request using the temp file
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
    -d "@$TEMP_PAYLOAD" \
    "${WP_URL}/wp-json/wp/v2/pages/${PAGE_ID}")

# Extract status code (last line)
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')

if [[ "$HTTP_STATUS" -ge 200 ]] && [[ "$HTTP_STATUS" -lt 300 ]]; then
    echo "✓ Successfully deployed $PAGE_TITLE"
else
    echo "✗ Failed to deploy $PAGE_TITLE (HTTP $HTTP_STATUS)"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi
