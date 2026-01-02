#!/bin/bash
# Bulk import all content of a specific type from WordPress
# Usage: ./bulk-import.sh <type> [wp-url]
#
# Examples:
#   ./bulk-import.sh posts
#   ./bulk-import.sh portfolio
#   ./bulk-import.sh posts https://your-site.com
#
# Requires WP_USERNAME and WP_APP_PASSWORD environment variables

set -e

POST_TYPE="$1"
WP_URL="${2:-${WP_BASE_URL:-https://example.com}}"

if [[ -z "$POST_TYPE" ]]; then
    echo "Usage: $0 <type> [wp-url]"
    echo ""
    echo "Types: posts, portfolio"
    echo ""
    echo "Requires WP_USERNAME and WP_APP_PASSWORD environment variables"
    exit 1
fi

if [[ -z "$WP_USERNAME" ]] || [[ -z "$WP_APP_PASSWORD" ]]; then
    echo "Error: WP_USERNAME and WP_APP_PASSWORD environment variables required"
    exit 1
fi

# Map type to API endpoint and directory
case "$POST_TYPE" in
    posts|post)
        API_ENDPOINT="posts"
        TYPE_DIR="posts"
        ;;
    portfolio)
        API_ENDPOINT="portfolio"
        TYPE_DIR="portfolio"
        ;;
    *)
        echo "Error: Unknown type: $POST_TYPE (use: posts, portfolio)"
        exit 1
        ;;
esac

echo "========================================"
echo "Bulk Import: $POST_TYPE"
echo "Source: $WP_URL"
echo "========================================"

# Create directories
mkdir -p "content/${TYPE_DIR}"
mkdir -p "meta/${TYPE_DIR}"

# Fetch all items (paginated)
PAGE=1
TOTAL=0
SUCCESS=0
FAILED=0

while true; do
    echo ""
    echo "Fetching page $PAGE..."
    
    RESPONSE=$(curl -s \
        -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
        "${WP_URL}/wp-json/wp/v2/${API_ENDPOINT}?per_page=100&page=${PAGE}&context=edit&status=publish,draft,private")
    
    # Check if we got an array
    if ! echo "$RESPONSE" | jq -e 'type == "array"' > /dev/null 2>&1; then
        if echo "$RESPONSE" | jq -e '.code' > /dev/null 2>&1; then
            ERROR=$(echo "$RESPONSE" | jq -r '.message')
            if [[ "$ERROR" == *"rest_post_invalid_page_number"* ]]; then
                break
            fi
            echo "Error: $ERROR"
            exit 1
        fi
        break
    fi
    
    COUNT=$(echo "$RESPONSE" | jq 'length')
    if [[ "$COUNT" -eq 0 ]]; then
        break
    fi
    
    # Process each item
    echo "$RESPONSE" | jq -c '.[]' | while read -r ITEM; do
        POST_ID=$(echo "$ITEM" | jq -r '.id')
        SLUG=$(echo "$ITEM" | jq -r '.slug')
        TITLE=$(echo "$ITEM" | jq -r '.title.rendered // .title.raw // .title')
        
        echo "----------------------------------------"
        echo "Processing: $SLUG (ID: $POST_ID)"
        
        # Try Enfold content first, then raw content
        CONTENT=$(echo "$ITEM" | jq -r '.meta._aviaLayoutBuilderCleanData // empty')
        CONTENT_SOURCE="enfold"
        
        if [[ -z "$CONTENT" ]] || [[ "$CONTENT" == "null" ]]; then
            CONTENT=$(echo "$ITEM" | jq -r '.content.raw // empty')
            CONTENT_SOURCE="raw"
        fi
        
        if [[ -z "$CONTENT" ]] || [[ "$CONTENT" == "null" ]]; then
            CONTENT=$(echo "$ITEM" | jq -r '.content.rendered // empty')
            CONTENT_SOURCE="rendered"
        fi
        
        if [[ -z "$CONTENT" ]] || [[ "$CONTENT" == "null" ]]; then
            echo "  ⚠ Warning: No content found, creating empty file"
            CONTENT=""
            CONTENT_SOURCE="empty"
        fi
        
        # Save content file
        CONTENT_FILE="content/${TYPE_DIR}/${SLUG}.txt"
        echo "$CONTENT" > "$CONTENT_FILE"
        BYTES=$(wc -c < "$CONTENT_FILE")
        echo "  ✓ $CONTENT_FILE ($BYTES bytes, $CONTENT_SOURCE)"
        
        # Save meta file
        META_FILE="meta/${TYPE_DIR}/${SLUG}.json"
        printf '{\n  "post_id": %s,\n  "title": %s,\n  "slug": "%s",\n  "type": "%s"\n}\n' \
            "$POST_ID" \
            "$(echo "$TITLE" | jq -R .)" \
            "$SLUG" \
            "$TYPE_DIR" > "$META_FILE"
        echo "  ✓ $META_FILE"
    done
    
    TOTAL=$((TOTAL + COUNT))
    
    if [[ "$COUNT" -lt 100 ]]; then
        break
    fi
    
    PAGE=$((PAGE + 1))
done

echo ""
echo "========================================"
echo "Import complete: $TOTAL items processed"
echo "Content saved to: content/${TYPE_DIR}/"
echo "Meta saved to: meta/${TYPE_DIR}/"
echo "========================================"
