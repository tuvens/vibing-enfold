#!/usr/bin/env python3
"""
Generate Enfold Theme Settings from Design Tokens

This script transforms a simple design-tokens.json file into the full
base64-encoded PHP serialized format that Enfold expects for theme import.

Usage:
    python3 generate-theme-settings.py <tokens_file> <base_url> [output_file]

Example:
    python3 generate-theme-settings.py theme/design-tokens.json https://your-site.com

The output can be POSTed to the WordPress REST API endpoint:
    POST /wp-json/enfold-gitops/v1/settings
"""

import sys
import json
import base64

def generate_enfold_settings(tokens: dict, base_url: str) -> dict:
    """
    Transform design tokens into Enfold's settings structure.
    
    Args:
        tokens: Design tokens from design-tokens.json
        base_url: WordPress site URL for resolving relative asset paths
    
    Returns:
        Complete Enfold settings dictionary
    """
    colors = tokens.get("colors", {})
    typography = tokens.get("typography", {})
    assets = tokens.get("assets", {})
    features = tokens.get("features", {})
    
    # Resolve relative asset URLs
    def resolve_url(path):
        if not path:
            return ""
        if path.startswith("http://") or path.startswith("https://"):
            return path
        return f"{base_url.rstrip('/')}{path}"
    
    # Build the full settings dictionary
    # This contains only the settings with actual values (std field)
    # Enfold will use its defaults for anything not specified
    settings = {
        # === Logo & Branding ===
        "logo": {
            "slug": "avia",
            "name": "Logo",
            "id": "logo",
            "type": "upload",
            "std": resolve_url(assets.get("logo", ""))
        },
        "favicon": {
            "slug": "avia",
            "name": "Favicon",
            "id": "favicon",
            "type": "upload",
            "std": resolve_url(assets.get("favicon", ""))
        },
        
        # === Features ===
        "preloader": {
            "slug": "avia",
            "name": "Page Preloading",
            "id": "preloader",
            "type": "checkbox",
            "std": "preloader" if features.get("page_preloading", True) else "disabled"
        },
        "preloader_transitions": {
            "slug": "avia",
            "name": "Page Transitions",
            "id": "preloader_transitions",
            "type": "checkbox",
            "std": "preloader_transitions" if features.get("page_transitions", True) else "disabled"
        },
        "lightbox_active": {
            "slug": "avia",
            "name": "Lightbox Modal Window",
            "id": "lightbox_active",
            "type": "checkbox",
            "std": "lightbox_active" if features.get("lightbox", True) else "disabled"
        },
        
        # === Typography ===
        "google_webfont": {
            "slug": "styling",
            "name": "Heading Font",
            "id": "google_webfont",
            "type": "select",
            "std": typography.get("heading_font", "")
        },
        "default_font": {
            "slug": "styling",
            "name": "Font For Your Body Text",
            "id": "default_font",
            "type": "select",
            "std": typography.get("body_font", "")
        },
        
        # === Header Color Set ===
        "colorset-header_color-bg": {
            "slug": "styling",
            "id": "colorset-header_color-bg",
            "type": "colorpicker",
            "std": colors.get("background", "#ffffff")
        },
        "colorset-header_color-bg2": {
            "slug": "styling",
            "id": "colorset-header_color-bg2",
            "type": "colorpicker",
            "std": colors.get("background_alt", "#f8f8f8")
        },
        "colorset-header_color-primary": {
            "slug": "styling",
            "id": "colorset-header_color-primary",
            "type": "colorpicker",
            "std": colors.get("secondary", "#0a364d")  # Dark for header
        },
        "colorset-header_color-secondary": {
            "slug": "styling",
            "id": "colorset-header_color-secondary",
            "type": "colorpicker",
            "std": colors.get("accent", "#179162")
        },
        "colorset-header_color-color": {
            "slug": "styling",
            "id": "colorset-header_color-color",
            "type": "colorpicker",
            "std": colors.get("accent", "#179162")  # Menu text
        },
        "colorset-header_color-meta": {
            "slug": "styling",
            "id": "colorset-header_color-meta",
            "type": "colorpicker",
            "std": colors.get("secondary", "#0a364d")
        },
        "colorset-header_color-heading": {
            "slug": "styling",
            "id": "colorset-header_color-heading",
            "type": "colorpicker",
            "std": colors.get("secondary", "#0a364d")
        },
        "colorset-header_color-border": {
            "slug": "styling",
            "id": "colorset-header_color-border",
            "type": "colorpicker",
            "std": colors.get("border", "#ebebeb")
        },
        
        # === Main Content Color Set ===
        "colorset-main_color-bg": {
            "slug": "styling",
            "id": "colorset-main_color-bg",
            "type": "colorpicker",
            "std": colors.get("background", "#ffffff")
        },
        "colorset-main_color-bg2": {
            "slug": "styling",
            "id": "colorset-main_color-bg2",
            "type": "colorpicker",
            "std": colors.get("background_alt", "#f8f8f8")
        },
        "colorset-main_color-primary": {
            "slug": "styling",
            "id": "colorset-main_color-primary",
            "type": "colorpicker",
            "std": colors.get("primary", "#409265")  # Links
        },
        "colorset-main_color-secondary": {
            "slug": "styling",
            "id": "colorset-main_color-secondary",
            "type": "colorpicker",
            "std": colors.get("secondary", "#0a364d")
        },
        "colorset-main_color-color": {
            "slug": "styling",
            "id": "colorset-main_color-color",
            "type": "colorpicker",
            "std": colors.get("text", "#000000")
        },
        "colorset-main_color-meta": {
            "slug": "styling",
            "id": "colorset-main_color-meta",
            "type": "colorpicker",
            "std": colors.get("secondary", "#0a364d")
        },
        "colorset-main_color-heading": {
            "slug": "styling",
            "id": "colorset-main_color-heading",
            "type": "colorpicker",
            "std": colors.get("secondary", "#0a364d")
        },
        "colorset-main_color-border": {
            "slug": "styling",
            "id": "colorset-main_color-border",
            "type": "colorpicker",
            "std": colors.get("border", "#ebebeb")
        },
        
        # === Alternate (Dark) Color Set ===
        "colorset-alternate_color-bg": {
            "slug": "styling",
            "id": "colorset-alternate_color-bg",
            "type": "colorpicker",
            "std": colors.get("secondary", "#0a364d")  # Dark background
        },
        "colorset-alternate_color-bg2": {
            "slug": "styling",
            "id": "colorset-alternate_color-bg2",
            "type": "colorpicker",
            "std": colors.get("secondary", "#0a364d")
        },
        "colorset-alternate_color-primary": {
            "slug": "styling",
            "id": "colorset-alternate_color-primary",
            "type": "colorpicker",
            "std": colors.get("background", "#ffffff")  # White on dark
        },
        "colorset-alternate_color-secondary": {
            "slug": "styling",
            "id": "colorset-alternate_color-secondary",
            "type": "colorpicker",
            "std": colors.get("background", "#ffffff")
        },
        "colorset-alternate_color-color": {
            "slug": "styling",
            "id": "colorset-alternate_color-color",
            "type": "colorpicker",
            "std": colors.get("background", "#ffffff")  # White text
        },
        "colorset-alternate_color-meta": {
            "slug": "styling",
            "id": "colorset-alternate_color-meta",
            "type": "colorpicker",
            "std": colors.get("border", "#ebebeb")
        },
        "colorset-alternate_color-heading": {
            "slug": "styling",
            "id": "colorset-alternate_color-heading",
            "type": "colorpicker",
            "std": colors.get("background", "#ffffff")
        },
        "colorset-alternate_color-border": {
            "slug": "styling",
            "id": "colorset-alternate_color-border",
            "type": "colorpicker",
            "std": colors.get("border", "#ebebeb")
        },
        
        # === Footer Color Set ===
        "colorset-footer_color-bg": {
            "slug": "styling",
            "id": "colorset-footer_color-bg",
            "type": "colorpicker",
            "std": colors.get("secondary", "#0a364d")  # Dark footer
        },
        "colorset-footer_color-bg2": {
            "slug": "styling",
            "id": "colorset-footer_color-bg2",
            "type": "colorpicker",
            "std": colors.get("background_alt", "#f8f8f8")
        },
        "colorset-footer_color-primary": {
            "slug": "styling",
            "id": "colorset-footer_color-primary",
            "type": "colorpicker",
            "std": colors.get("primary", "#409265")
        },
        "colorset-footer_color-secondary": {
            "slug": "styling",
            "id": "colorset-footer_color-secondary",
            "type": "colorpicker",
            "std": colors.get("background", "#ffffff")
        },
        "colorset-footer_color-color": {
            "slug": "styling",
            "id": "colorset-footer_color-color",
            "type": "colorpicker",
            "std": colors.get("background", "#ffffff")  # White text
        },
        "colorset-footer_color-meta": {
            "slug": "styling",
            "id": "colorset-footer_color-meta",
            "type": "colorpicker",
            "std": colors.get("text_muted", "#969696")
        },
        "colorset-footer_color-heading": {
            "slug": "styling",
            "id": "colorset-footer_color-heading",
            "type": "colorpicker",
            "std": colors.get("background", "#ffffff")
        },
        "colorset-footer_color-border": {
            "slug": "styling",
            "id": "colorset-footer_color-border",
            "type": "colorpicker",
            "std": colors.get("border", "#ebebeb")
        },
        
        # === Socket (Bottom Footer) Color Set ===
        "colorset-socket_color-bg": {
            "slug": "styling",
            "id": "colorset-socket_color-bg",
            "type": "colorpicker",
            "std": colors.get("background", "#ffffff")
        },
        "colorset-socket_color-bg2": {
            "slug": "styling",
            "id": "colorset-socket_color-bg2",
            "type": "colorpicker",
            "std": colors.get("background_alt", "#f8f8f8")
        },
        "colorset-socket_color-primary": {
            "slug": "styling",
            "id": "colorset-socket_color-primary",
            "type": "colorpicker",
            "std": colors.get("primary", "#409265")
        },
        "colorset-socket_color-secondary": {
            "slug": "styling",
            "id": "colorset-socket_color-secondary",
            "type": "colorpicker",
            "std": colors.get("primary", "#409265")
        },
        "colorset-socket_color-color": {
            "slug": "styling",
            "id": "colorset-socket_color-color",
            "type": "colorpicker",
            "std": colors.get("secondary", "#0a364d")
        },
        "colorset-socket_color-meta": {
            "slug": "styling",
            "id": "colorset-socket_color-meta",
            "type": "colorpicker",
            "std": colors.get("text_muted", "#969696")
        },
        "colorset-socket_color-heading": {
            "slug": "styling",
            "id": "colorset-socket_color-heading",
            "type": "colorpicker",
            "std": colors.get("text", "#000000")
        },
        "colorset-socket_color-border": {
            "slug": "styling",
            "id": "colorset-socket_color-border",
            "type": "colorpicker",
            "std": colors.get("border", "#ebebeb")
        },
        
        # === Body Background ===
        "color-body_color": {
            "slug": "styling",
            "id": "color-body_color",
            "type": "colorpicker",
            "std": "#eeeeee"  # Page background behind content
        },
    }
    
    # Add preloader logo if specified
    if assets.get("preloader_logo"):
        settings["preloader_logo"] = {
            "slug": "avia",
            "name": "Custom Logo for preloader",
            "id": "preloader_logo",
            "type": "upload",
            "std": resolve_url(assets.get("preloader_logo"))
        }
    
    return settings


def serialize_php(data):
    """
    Serialize Python data to PHP serialize() format.
    
    This is a simplified implementation that handles the types
    we need for Enfold settings (strings, ints, bools, dicts, lists).
    """
    if data is None:
        return "N;"
    elif isinstance(data, bool):
        return f"b:{1 if data else 0};"
    elif isinstance(data, int):
        return f"i:{data};"
    elif isinstance(data, float):
        return f"d:{data};"
    elif isinstance(data, str):
        return f's:{len(data.encode("utf-8"))}:"{data}";'
    elif isinstance(data, list):
        items = "".join(
            f"{serialize_php(i)}{serialize_php(v)}"
            for i, v in enumerate(data)
        )
        return f"a:{len(data)}:{{{items}}}"
    elif isinstance(data, dict):
        items = "".join(
            f"{serialize_php(k)}{serialize_php(v)}"
            for k, v in data.items()
        )
        return f"a:{len(data)}:{{{items}}}"
    else:
        raise TypeError(f"Cannot serialize type: {type(data)}")


def main():
    if len(sys.argv) < 3:
        print("Usage: generate-theme-settings.py <tokens_file> <base_url> [output_file]")
        print("Example: generate-theme-settings.py theme/design-tokens.json https://example.com")
        sys.exit(1)
    
    tokens_file = sys.argv[1]
    base_url = sys.argv[2]
    output_file = sys.argv[3] if len(sys.argv) > 3 else None
    
    # Load design tokens
    with open(tokens_file, 'r') as f:
        tokens = json.load(f)
    
    # Generate Enfold settings
    settings = generate_enfold_settings(tokens, base_url)
    
    # Wrap in expected structure
    full_settings = {
        "avia": settings,
        "avia_ext": {}
    }
    
    # Serialize and encode
    serialized = serialize_php(full_settings)
    encoded = base64.b64encode(serialized.encode('utf-8')).decode('utf-8')
    
    if output_file:
        with open(output_file, 'w') as f:
            f.write(encoded)
        print(f"Generated settings written to: {output_file}")
        print(f"Settings count: {len(settings)}")
    else:
        # Output to stdout for piping
        print(encoded)


if __name__ == "__main__":
    main()
