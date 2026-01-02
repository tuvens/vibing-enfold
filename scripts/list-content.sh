#!/bin/bash
# List all content of a specific type from WordPress
# Usage: ./list-content.sh <type> [wp-url]
#
# Examples:
#   ./list-content.sh posts
#   ./list-content.sh portfolio
#   ./list-content.sh layouts

set -e

POST_TYPE="$1"
WP_URL="${2:-${WP_BASE_URL:-https://example.com}}"

if [[ -z "$POST_TYPE" ]]; then
    echo "Usage: $0 <type> [wp-url]"
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
        echo "Error: Unknown type: $POST_TYPE (use: pages, posts, portfolio, layouts)"
        exit 1
        ;;
esac

echo "Listing $POST_TYPE from $WP_URL"
echo "========================================"

# Fetch all items (paginated)
PAGE=1
TOTAL=0

while true; do
    RESPONSE=$(curl -s \
        -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
        "${WP_URL}/wp-json/wp/v2/${API_ENDPOINT}?per_page=100&page=${PAGE}&status=publish,draft,private")
    
    # Check if we got an array
    if ! echo "$RESPONSE" | jq -e 'type == "array"' > /dev/null 2>&1; then
        # Might be an error or end of results
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
    
    # Output each item
    echo "$RESPONSE" | jq -r '.[] | "\(.id)\t\(.slug)\t\(.title.rendered // .title)"'
    
    TOTAL=$((TOTAL + COUNT))
    
    if [[ "$COUNT" -lt 100 ]]; then
        break
    fi
    
    PAGE=$((PAGE + 1))
done

echo "========================================"
echo "Total: $TOTAL items"
