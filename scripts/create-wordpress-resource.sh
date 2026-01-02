#!/bin/bash
# Create new WordPress resource from content file
# Usage: ./create-wordpress-resource.sh <content-file> <wp-url> <username> <app-password>
#
# Content file format (YAML frontmatter):
# ---
# title: Page Title
# slug: page-slug
# status: draft|publish
# ---
# [Enfold shortcode content...]

set -e

CONTENT_FILE="$1"
WP_URL="$2"
WP_USERNAME="$3"
WP_APP_PASSWORD="$4"

if [[ -z "$CONTENT_FILE" ]] || [[ -z "$WP_URL" ]] || [[ -z "$WP_USERNAME" ]] || [[ -z "$WP_APP_PASSWORD" ]]; then
    echo "Usage: $0 <content-file> <wp-url> <username> <app-password>"
    exit 1
fi

if [[ ! -f "$CONTENT_FILE" ]]; then
    echo "❌ Content file not found: $CONTENT_FILE"
    exit 1
fi

# Extract path components: content/[type]/[name].txt -> type, name
CONTENT_PATH="${CONTENT_FILE#content/}"
if [[ "$CONTENT_PATH" == *"/"* ]]; then
    POST_TYPE="${CONTENT_PATH%%/*}"
    BASENAME=$(basename "$CONTENT_FILE" .txt)
else
    # Legacy: content/[name].txt -> pages
    POST_TYPE="pages"
    BASENAME=$(basename "$CONTENT_FILE" .txt)
fi

# Map post type to REST API endpoint
case "$POST_TYPE" in
    pages|page)
        API_ENDPOINT="pages"
        META_TYPE="pages"
        ;;
    posts|post)
        API_ENDPOINT="posts"
        META_TYPE="posts"
        ;;
    portfolio)
        API_ENDPOINT="portfolio"
        META_TYPE="portfolio"
        ;;
    layouts|alb_custom_layout)
        API_ENDPOINT="alb_custom_layout"
        META_TYPE="layouts"
        ;;
    *)
        echo "❌ Unknown content type: $POST_TYPE"
        echo "   Expected: pages, posts, portfolio, or layouts"
        exit 1
        ;;
esac

# Extract YAML frontmatter field using grep and sed (simpler, avoids quoting issues)
extract_field() {
    local field="$1"
    local default="$2"
    local value
    
    # Extract field value from frontmatter (between first and second ---)
    value=$(sed -n '1,/^---$/{ /^---$/d; p; }' "$CONTENT_FILE" | \
            sed -n '1,/^---$/p' | \
            grep "^${field}:" | \
            sed "s/^${field}: *//" | \
            sed 's/^["'"'"']//' | \
            sed 's/["'"'"']$//' | \
            head -1)
    
    if [[ -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Check if file has frontmatter
HAS_FRONTMATTER=$(head -1 "$CONTENT_FILE" | grep -c '^---$' || true)

if [[ "$HAS_FRONTMATTER" -eq 1 ]]; then
    TITLE=$(extract_field "title" "")
    SLUG=$(extract_field "slug" "$BASENAME")
    STATUS=$(extract_field "status" "publish")
else
    # No frontmatter - use filename as slug, require title to be set
    TITLE=""
    SLUG="$BASENAME"
    STATUS="publish"
fi

# Validate required fields
if [[ -z "$TITLE" ]]; then
    echo "❌ Missing required field: title"
    echo "   Add YAML frontmatter to $CONTENT_FILE:"
    echo "   ---"
    echo "   title: Your Page Title"
    echo "   slug: your-page-slug"
    echo "   status: publish"
    echo "   ---"
    exit 1
fi

# Extract content (everything after the closing ---)
if [[ "$HAS_FRONTMATTER" -eq 1 ]]; then
    CONTENT=$(awk '
        BEGIN { in_content=0; count=0 }
        /^---$/ { 
            count++
            if (count == 2) { in_content=1; next }
        }
        in_content { print }
    ' "$CONTENT_FILE")
else
    CONTENT=$(cat "$CONTENT_FILE")
fi

# Create temporary file for JSON payload
TEMP_PAYLOAD=$(mktemp)
trap "rm -f $TEMP_PAYLOAD" EXIT

# Build JSON payload with Enfold meta fields
jq -n \
    --arg title "$TITLE" \
    --arg slug "$SLUG" \
    --arg status "$STATUS" \
    --arg content "$CONTENT" \
    '{
        title: $title,
        slug: $slug,
        status: $status,
        content: $content,
        meta: {
            "_aviaLayoutBuilderCleanData": $content,
            "_aviaLayoutBuilder_active": "active"
        }
    }' > "$TEMP_PAYLOAD"

echo "Creating $META_TYPE: $TITLE"
echo "  Slug: $SLUG"
echo "  Status: $STATUS"
echo "  Content: $(echo "$CONTENT" | wc -c) bytes"
echo "  Target: $WP_URL/wp-json/wp/v2/$API_ENDPOINT"

# Create the resource via WordPress REST API
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
    -d "@$TEMP_PAYLOAD" \
    "${WP_URL}/wp-json/wp/v2/${API_ENDPOINT}")

HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')

if [[ "$HTTP_STATUS" -ge 200 ]] && [[ "$HTTP_STATUS" -lt 300 ]]; then
    POST_ID=$(echo "$RESPONSE_BODY" | jq -r '.id')
    POST_LINK=$(echo "$RESPONSE_BODY" | jq -r '.link')
    
    echo "✅ Created successfully!"
    echo "   ID: $POST_ID"
    echo "   URL: $POST_LINK"
    
    # Create meta directory if needed
    META_DIR="meta/${META_TYPE}"
    mkdir -p "$META_DIR"
    
    # Create meta JSON file
    META_FILE="${META_DIR}/${BASENAME}.json"
    jq -n \
        --argjson post_id "$POST_ID" \
        --arg title "$TITLE" \
        --arg slug "$SLUG" \
        --arg type "$POST_TYPE" \
        '{
            post_id: $post_id,
            title: $title,
            slug: $slug,
            type: $type
        }' > "$META_FILE"
    
    echo "   Meta: $META_FILE"
    
    # Output the meta file path for GitHub Actions to commit
    echo "META_FILE=$META_FILE" >> "${GITHUB_OUTPUT:-/dev/null}"
    
    exit 0
else
    echo "❌ Failed to create $META_TYPE"
    echo "   HTTP Status: $HTTP_STATUS"
    echo "   Response: $RESPONSE_BODY"
    exit 1
fi
