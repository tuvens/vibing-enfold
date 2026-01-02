#!/bin/bash
# Validate that a content file contains Enfold shortcodes, not rendered HTML
# Usage: ./validate-content.sh <content-file>

set -e

FILE="$1"

if [[ -z "$FILE" ]]; then
    echo "Usage: $0 <content-file>"
    exit 1
fi

if [[ ! -f "$FILE" ]]; then
    echo "ERROR: File not found: $FILE"
    exit 1
fi

# Check file size
SIZE=$(wc -c < "$FILE")
if [[ $SIZE -lt 10 ]]; then
    echo "ERROR: File is too small ($SIZE bytes) - content may be empty"
    exit 1
fi

# Check for HTML indicators (BAD)
if grep -q '<div.*class=' "$FILE" 2>/dev/null; then
    echo "ERROR: File contains rendered HTML (<div class=...), not shortcodes!"
    echo "First 200 chars:"
    head -c 200 "$FILE"
    exit 1
fi

if grep -q '<form.*action=' "$FILE" 2>/dev/null; then
    echo "ERROR: File contains rendered HTML (<form...), not shortcodes!"
    exit 1
fi

# Check for shortcode indicators (GOOD)
if grep -q '\[av_' "$FILE" 2>/dev/null; then
    echo "✓ File contains Enfold shortcodes"
    echo "First shortcode found:"
    grep -o '\[av_[a-z_]*' "$FILE" | head -1
    exit 0
fi

# Check for WordPress shortcodes (also acceptable)
if grep -q '<!-- wp:shortcode -->' "$FILE" 2>/dev/null; then
    echo "✓ File contains WordPress shortcodes with Enfold content"
    exit 0
fi

# If we get here, content is suspicious
echo "WARNING: File doesn't contain obvious shortcodes or HTML"
echo "First 300 chars:"
head -c 300 "$FILE"
echo ""
echo "Please manually verify this is correct shortcode content."
exit 1
