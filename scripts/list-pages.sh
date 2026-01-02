#!/bin/bash
# List all pages from WordPress
# Requires: WP_USERNAME, WP_APP_PASSWORD, WP_BASE_URL environment variables

set -e

if [[ -z "$WP_USERNAME" ]] || [[ -z "$WP_APP_PASSWORD" ]] || [[ -z "$WP_BASE_URL" ]]; then
    echo "Required environment variables:"
    echo "  WP_USERNAME - WordPress username"
    echo "  WP_APP_PASSWORD - WordPress application password"
    echo "  WP_BASE_URL - WordPress site URL (e.g., https://your-site.com)"
    exit 1
fi

echo "Fetching pages from $WP_BASE_URL..."
echo ""

curl -s \
    -u "${WP_USERNAME}:${WP_APP_PASSWORD}" \
    "${WP_BASE_URL}/wp-json/wp/v2/pages?per_page=100" | \
    jq -r '.[] | "\(.id)\t\(.slug)\t\(.title.rendered)"' | \
    column -t -s $'\t'
