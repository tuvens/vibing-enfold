#!/bin/bash
# Pull a page from WordPress to local files
# Usage: ./pull-page.sh <page-id> <filename>
# Requires: WP_USERNAME, WP_APP_PASSWORD, WP_BASE_URL environment variables

set -e

PAGE_ID="$1"
FILENAME="$2"

if [[ -z "$PAGE_ID" ]] || [[ -z "$FILENAME" ]]; then
    echo "Usage: $0 <page-id> <filename>"
    echo "Example: $0 123 home"
    echo ""
    echo "Required environment variables:"
    echo "  WP_USERNAME - WordPress username"
    echo "  WP_APP_PASSWORD - WordPress application password"
    echo "  WP_BASE_URL - WordPress site URL (e.g., https://your-site.com)"
    exit 1
fi

if [[ -z "$WP_USERNAME" ]] || [[ -z "$WP_APP_PASSWORD" ]] || [[ -z "$WP_BASE_URL" ]]; then
    echo "Error: Missing required environment variables"
    exit 1
fi

echo "Fetching page $PAGE_ID from $WP_BASE_URL..."

# Fetch the page
RESPONSE=$(curl -s \
    -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
    "${WP_BASE_URL}/wp-json/wp/v2/pages/${PAGE_ID}?context=edit")

# Extract fields
TITLE=$(echo "$RESPONSE" | jq -r '.title.rendered')
SLUG=$(echo "$RESPONSE" | jq -r '.slug')
CONTENT=$(echo "$RESPONSE" | jq -r '.content.raw // .content.rendered')

if [[ -z "$TITLE" ]] || [[ "$TITLE" == "null" ]]; then
    echo "Error: Could not fetch page. Response:"
    echo "$RESPONSE"
    exit 1
fi

# Save content file
echo "$CONTENT" > "content/${FILENAME}.txt"
echo "Saved content to content/${FILENAME}.txt"

# Save meta file
jq -n \
    --arg page_id "$PAGE_ID" \
    --arg title "$TITLE" \
    --arg slug "$SLUG" \
    '{page_id: ($page_id | tonumber), title: $title, slug: $slug}' > "meta/${FILENAME}.json"
echo "Saved meta to meta/${FILENAME}.json"

echo "Done! Pulled: $TITLE"
