# Enfold REST API Meta Support

A WordPress plugin that exposes Enfold page builder meta fields and theme settings to the REST API, enabling GitOps deployment workflows.

## Purpose

This plugin provides two capabilities for the GitOps workflow:

1. **Page Builder Meta Fields** - Exposes `_aviaLayoutBuilderCleanData` and `_aviaLayoutBuilder_active` to the REST API, allowing GitHub Actions to update page content programmatically.

2. **Theme Settings API** - Provides REST endpoints to export and import Enfold theme settings, enabling design token-based theme configuration management.

## Installation

1. Upload the `enfold-rest-meta` folder to `/wp-content/plugins/`
2. Activate the plugin through the WordPress Admin → Plugins menu

## REST API Endpoints

### Page/Post Meta Fields

Once activated, you can update Enfold content via the standard WP REST API:

```bash
curl -X POST "https://yoursite.com/wp-json/wp/v2/pages/123" \
  -u "username:app-password" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "[av_section]...[/av_section]",
    "meta": {
      "_aviaLayoutBuilderCleanData": "[av_section]...[/av_section]",
      "_aviaLayoutBuilder_active": "active"
    }
  }'
```

### Theme Settings API

#### Export Settings

```bash
# GET current theme settings
curl "https://yoursite.com/wp-json/enfold-gitops/v1/settings" \
  -u "username:app-password"
```

Response:
```json
{
  "success": true,
  "data": "<base64-encoded PHP serialized settings>",
  "settings_count": 447,
  "timestamp": "2025-01-01T00:00:00+00:00"
}
```

#### Import Settings

```bash
# POST new theme settings
curl -X POST "https://yoursite.com/wp-json/enfold-gitops/v1/settings" \
  -u "username:app-password" \
  -H "Content-Type: application/json" \
  -d '{
    "settings": "<base64-encoded PHP serialized settings>"
  }'
```

Response:
```json
{
  "success": true,
  "message": "Enfold settings updated successfully",
  "settings_count": 45,
  "merged_total": 447,
  "timestamp": "2025-01-01T00:00:00+00:00"
}
```

## GitOps Workflow

This plugin works with the GitHub Actions workflow to enable:

1. **Content Deployment** - Push changes to `content/` files to update WordPress pages/posts
2. **Theme Settings** - Edit `theme/design-tokens.json` to update site colors, fonts, and branding

### Design Tokens → Theme Settings Flow

```
theme/design-tokens.json (simple JSON)
        ↓
scripts/generate-theme-settings.py (transforms to Enfold format)
        ↓
GitHub Actions (posts to REST API)
        ↓
This Plugin (imports settings, regenerates CSS)
        ↓
Enfold Theme (displays updated styling)
```

## Supported Post Types

- `page` - Standard WordPress pages
- `post` - Blog posts
- `portfolio` - Enfold portfolio items
- `alb_custom_layout` - Enfold custom layouts (headers/footers)

## Security

- Meta field access requires `edit_posts` capability
- Theme settings endpoints require `manage_options` capability (admin only)
- Uses WordPress's built-in authentication (Application Passwords recommended)

## Cache Handling

After importing theme settings, the plugin automatically:

1. Clears Enfold's dynamic CSS transients
2. Flushes WordPress object cache
3. Triggers cache purge for common caching plugins:
   - SiteGround Optimizer
   - WP Super Cache
   - W3 Total Cache
   - LiteSpeed Cache
   - WP Rocket

## Requirements

- WordPress 5.0+
- Enfold theme (any version with Advanced Layout Builder)
- PHP 7.4+

## Changelog

### 2.2.0
- Genericized for vibing-enfold template repository

### 1.1.0
- Added theme settings REST API endpoints (GET/POST)
- Added automatic CSS regeneration after settings import
- Added cache clearing for popular caching plugins
- Added admin notice about GitOps features

### 1.0.0
- Initial release
- Exposes Enfold builder meta fields to REST API

## License

GPL v2 or later
