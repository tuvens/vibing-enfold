#!/bin/bash
# Pull content from WordPress (pages, posts, portfolio, layouts)
# Usage: ./pull-content.sh <type> <post-id> <name> [wp-url]
#
# Examples:
#   ./pull-content.sh posts 123 my-blog-post
#   ./pull-content.sh portfolio 456 festival-name
#   ./pull-content.sh layouts 789 header-layout

set -e

POST_TYPE="$1"
POST_ID="$2"
NAME="$3"
WP_URL="${4:-${WP_BASE_URL:-https://example.com}}"

if [[ -z "$POST_TYPE" ]] || [[ -z "$POST_ID" ]] || [[ -z "$NAME" ]]; then
    echo "Usage: $0 <type> <post-id> <name> [wp-url]"
    echo ""
    echo "Types: pages, posts, portfolio, layouts"
    echo ""
    echo "Requires WP_USERNAME and WP_APP_PASSWORD environment variables"
    exit 1
fi

if [[ -z "$WP_USERNAME" ]] || [[ -z "$WP_APP_PASSWORD" ]]; then
    echo "Error: WP_USERNAME and WP_APP_PASSWORD environment variables required"
    exit 1
fi

# Map type to API endpoint
case "$POST_TYPE" in
    pages|page)
        API_ENDPOINT="pages"
        TYPE_DIR="pages"
        ;;
    posts|post)
        API_ENDPOINT="posts"
        TYPE_DIR="posts"
        ;;
    portfolio)
        API_ENDPOINT="portfolio"
        TYPE_DIR="portfolio"
        ;;
    layouts|alb_custom_layout)
        API_ENDPOINT="alb_custom_layout"
        TYPE_DIR="layouts"
        ;;
    *)
        echo "Error: Unknown type: $POST_TYPE (use: pages, posts, portfolio, layouts)"
        exit 1
        ;;
esac

echo "Pulling: $POST_TYPE/$NAME (ID: $POST_ID)"
echo "From: $WP_URL"

# Create directories
mkdir -p "content/${TYPE_DIR}"
mkdir -p "meta/${TYPE_DIR}"

# Fetch from WordPress
RESPONSE=$(curl -s \
    -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
    "${WP_URL}/wp-json/wp/v2/${API_ENDPOINT}/${POST_ID}")

# Check for error
if echo "$RESPONSE" | jq -e '.code' > /dev/null 2>&1; then
    echo "Error: $(echo "$RESPONSE" | jq -r '.message')"
    exit 1
fi

# Extract fields
TITLE=$(echo "$RESPONSE" | jq -r '.title.rendered // .title')
SLUG=$(echo "$RESPONSE" | jq -r '.slug')

# Try to get Enfold content first, fall back to regular content
CONTENT=$(echo "$RESPONSE" | jq -r '.meta._aviaLayoutBuilderCleanData // empty')
if [[ -z "$CONTENT" ]]; then
    # Try raw content
    CONTENT=$(echo "$RESPONSE" | jq -r '.content.raw // .content.rendered // empty')
fi

if [[ -z "$CONTENT" ]]; then
    echo "Warning: No content found for $POST_TYPE $POST_ID"
    CONTENT=""
fi

# Save content file
CONTENT_FILE="content/${TYPE_DIR}/${NAME}.txt"
echo "$CONTENT" > "$CONTENT_FILE"
echo "Saved: $CONTENT_FILE ($(wc -c < "$CONTENT_FILE") bytes)"

# Save meta file
META_FILE="meta/${TYPE_DIR}/${NAME}.json"
jq -n \
    --arg post_id "$POST_ID" \
    --arg title "$TITLE" \
    --arg slug "$SLUG" \
    --arg type "$POST_TYPE" \
    '{
        post_id: ($post_id | tonumber),
        title: $title,
        slug: $slug,
        type: $type
    }' > "$META_FILE"
echo "Saved: $META_FILE"

echo "✓ Done"
