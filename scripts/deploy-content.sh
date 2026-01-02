#!/bin/bash
# Deploy content to WordPress (pages, posts, portfolio, layouts)
# Usage: ./deploy-content.sh <content-file> <wp-url> <username> <app-password>

set -e

CONTENT_FILE="$1"
WP_URL="$2"
WP_USERNAME="$3"
WP_APP_PASSWORD="$4"

if [[ -z "$CONTENT_FILE" ]] || [[ -z "$WP_URL" ]] || [[ -z "$WP_USERNAME" ]] || [[ -z "$WP_APP_PASSWORD" ]]; then
    echo "Usage: $0 <content-file> <wp-url> <username> <app-password>"
    exit 1
fi

# Extract path components: content/[type]/[name].txt -> type, name
# Also support legacy: content/[name].txt -> pages, name
CONTENT_PATH="${CONTENT_FILE#content/}"
if [[ "$CONTENT_PATH" == *"/"* ]]; then
    POST_TYPE="${CONTENT_PATH%%/*}"
    BASENAME=$(basename "$CONTENT_FILE" .txt)
else
    POST_TYPE="pages"
    BASENAME=$(basename "$CONTENT_FILE" .txt)
fi

# Determine meta file location
if [[ -f "meta/${POST_TYPE}/${BASENAME}.json" ]]; then
    META_FILE="meta/${POST_TYPE}/${BASENAME}.json"
elif [[ -f "meta/${BASENAME}.json" ]]; then
    # Legacy location
    META_FILE="meta/${BASENAME}.json"
else
    echo "Error: Meta file not found for $BASENAME"
    exit 1
fi

if [[ ! -f "$CONTENT_FILE" ]]; then
    echo "Error: Content file not found: $CONTENT_FILE"
    exit 1
fi

# Read metadata
POST_ID=$(jq -r '.post_id // .page_id' "$META_FILE")
POST_TITLE=$(jq -r '.title' "$META_FILE")
TYPE_OVERRIDE=$(jq -r '.type // empty' "$META_FILE")

# Allow meta file to override detected type
if [[ -n "$TYPE_OVERRIDE" ]]; then
    POST_TYPE="$TYPE_OVERRIDE"
fi

if [[ -z "$POST_ID" ]] || [[ "$POST_ID" == "null" ]]; then
    echo "Error: No post_id/page_id found in $META_FILE"
    exit 1
fi

# Map post type to REST API endpoint
case "$POST_TYPE" in
    pages|page)
        API_ENDPOINT="pages"
        ;;
    posts|post)
        API_ENDPOINT="posts"
        ;;
    portfolio)
        API_ENDPOINT="portfolio"
        ;;
    layouts|alb_custom_layout)
        API_ENDPOINT="alb_custom_layout"
        ;;
    *)
        echo "Error: Unknown post type: $POST_TYPE"
        exit 1
        ;;
esac

echo "Deploying: $POST_TITLE (ID: $POST_ID, Type: $POST_TYPE)"
echo "Content file: $CONTENT_FILE ($(wc -c < "$CONTENT_FILE") bytes)"
echo "Target: $WP_URL/wp-json/wp/v2/$API_ENDPOINT/$POST_ID"

# Build JSON payload
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

# Make the API request
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
    -d "@$TEMP_PAYLOAD" \
    "${WP_URL}/wp-json/wp/v2/${API_ENDPOINT}/${POST_ID}")

# Extract status code
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')

if [[ "$HTTP_STATUS" -ge 200 ]] && [[ "$HTTP_STATUS" -lt 300 ]]; then
    echo "✓ Successfully deployed $POST_TITLE"
else
    echo "✗ Failed to deploy $POST_TITLE (HTTP $HTTP_STATUS)"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi
