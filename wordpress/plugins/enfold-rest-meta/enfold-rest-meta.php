<?php
/**
 * Plugin Name: Enfold REST API Meta Support
 * Plugin URI: https://github.com/tuvens/vibing-enfold
 * Description: Exposes Enfold builder meta fields and theme settings to REST API for GitOps deployment
 * Version: 2.2.0
 * Author: vibing-enfold
 * License: GPL v2 or later
 * License URI: https://www.gnu.org/licenses/gpl-2.0.html
 *
 * This plugin is required for the GitOps workflow to function.
 * It provides three capabilities:
 * 
 * 1. REST API for Enfold Post Types - Enables REST API access for portfolio,
 *    avia_layout_builder, and alb_custom_layout post types.
 *
 * 2. Page Builder Meta Fields - Exposes Enfold's _aviaLayoutBuilderCleanData and
 *    _aviaLayoutBuilder_active fields to the REST API for content deployment.
 *
 * 3. Theme Settings API - Provides endpoints to export and import Enfold theme
 *    settings, enabling GitOps-based theme configuration management.
 *
 * Installation:
 * 1. Upload this file to wp-content/plugins/enfold-rest-meta/
 * 2. Activate the plugin in WordPress Admin → Plugins
 *
 * REST Endpoints:
 * - GET/POST /wp-json/wp/v2/pages/{id}/meta (standard WP meta access)
 * - GET/POST /wp-json/wp/v2/portfolio/{id} (portfolio items)
 * - GET/POST /wp-json/wp/v2/alb_custom_layout/{id} (custom layouts)
 * - GET  /wp-json/enfold-gitops/v1/settings  (export theme settings)
 * - POST /wp-json/enfold-gitops/v1/settings  (import theme settings)
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

/**
 * Enable REST API for Enfold custom post types
 * 
 * Enfold registers portfolio, avia_layout_builder, and alb_custom_layout
 * without REST API support. This filter adds it during their registration.
 */
add_filter('register_post_type_args', function($args, $post_type) {
    if (in_array($post_type, ['portfolio', 'avia_layout_builder', 'alb_custom_layout'])) {
        $args['show_in_rest'] = true;
        if (empty($args['rest_base'])) {
            $args['rest_base'] = $post_type;
        }
    }
    return $args;
}, 10, 2);

/**
 * Register Enfold meta fields for REST API access
 * 
 * Priority 99 ensures all post types are registered first
 */
add_action('init', function() {
    $post_types = ['page', 'post', 'portfolio', 'alb_custom_layout'];
    
    foreach ($post_types as $post_type) {
        register_post_meta($post_type, '_aviaLayoutBuilderCleanData', [
            'show_in_rest' => true,
            'single' => true,
            'type' => 'string',
            'auth_callback' => function() {
                return current_user_can('edit_posts');
            }
        ]);
        
        register_post_meta($post_type, '_aviaLayoutBuilder_active', [
            'show_in_rest' => true,
            'single' => true,
            'type' => 'string',
            'auth_callback' => function() {
                return current_user_can('edit_posts');
            }
        ]);
    }
}, 99);

/**
 * Register theme settings REST API endpoints
 */
add_action('rest_api_init', function() {
    register_rest_route('enfold-gitops/v1', '/settings', [
        [
            'methods' => 'GET',
            'callback' => 'enfold_gitops_get_settings',
            'permission_callback' => function() {
                return current_user_can('manage_options');
            }
        ],
        [
            'methods' => 'POST',
            'callback' => 'enfold_gitops_update_settings',
            'permission_callback' => function() {
                return current_user_can('manage_options');
            }
        ]
    ]);
});

/**
 * Export current Enfold theme settings
 * 
 * Returns settings in base64-encoded PHP serialized format,
 * matching Enfold's native export format.
 * 
 * @return WP_REST_Response|WP_Error
 */
function enfold_gitops_get_settings() {
    $avia = get_option('avia');
    $avia_ext = get_option('avia_ext', []);
    
    if (!$avia) {
        return new WP_Error(
            'no_settings',
            'Enfold settings not found. Is Enfold theme active?',
            ['status' => 404]
        );
    }
    
    // Build export data matching Enfold's format
    $data = serialize(['avia' => $avia, 'avia_ext' => $avia_ext]);
    
    return rest_ensure_response([
        'success' => true,
        'data' => base64_encode($data),
        'settings_count' => is_array($avia) ? count($avia) : 0,
        'timestamp' => current_time('c')
    ]);
}

/**
 * Import Enfold theme settings from base64-encoded data
 * 
 * Accepts settings in the same format as Enfold's export/import feature.
 * After importing, triggers Enfold's dynamic CSS regeneration.
 * 
 * @param WP_REST_Request $request
 * @return WP_REST_Response|WP_Error
 */
function enfold_gitops_update_settings(WP_REST_Request $request) {
    $encoded_data = $request->get_param('settings');
    
    if (empty($encoded_data)) {
        return new WP_Error(
            'missing_settings',
            'No settings data provided. Send {"settings": "<base64 data>"}',
            ['status' => 400]
        );
    }
    
    // Decode base64
    $decoded = base64_decode($encoded_data, true);
    if ($decoded === false) {
        return new WP_Error(
            'decode_error',
            'Invalid base64 encoding',
            ['status' => 400]
        );
    }
    
    // Unserialize PHP data
    $settings = @unserialize($decoded);
    if ($settings === false && $decoded !== 'b:0;') {
        return new WP_Error(
            'unserialize_error',
            'Invalid PHP serialized data',
            ['status' => 400]
        );
    }
    
    // Validate structure
    if (!isset($settings['avia']) || !is_array($settings['avia'])) {
        return new WP_Error(
            'invalid_structure',
            'Missing or invalid "avia" settings array',
            ['status' => 400]
        );
    }
    
    // Get existing settings to merge (preserve settings not in the update)
    $existing_avia = get_option('avia', []);
    
    // Merge new settings over existing (new values override, existing preserved if not set)
    if (is_array($existing_avia)) {
        $merged_avia = array_merge($existing_avia, $settings['avia']);
    } else {
        $merged_avia = $settings['avia'];
    }
    
    // Update the main settings
    $updated = update_option('avia', $merged_avia);
    
    // Update extended settings if provided
    if (isset($settings['avia_ext']) && is_array($settings['avia_ext'])) {
        $existing_ext = get_option('avia_ext', []);
        if (is_array($existing_ext)) {
            $merged_ext = array_merge($existing_ext, $settings['avia_ext']);
        } else {
            $merged_ext = $settings['avia_ext'];
        }
        update_option('avia_ext', $merged_ext);
    }
    
    // Trigger Enfold's dynamic CSS regeneration
    enfold_gitops_regenerate_css();
    
    // Clear caches
    enfold_gitops_clear_caches();
    
    return rest_ensure_response([
        'success' => true,
        'message' => 'Enfold settings updated successfully',
        'settings_count' => count($settings['avia']),
        'merged_total' => count($merged_avia),
        'timestamp' => current_time('c')
    ]);
}

/**
 * Trigger Enfold's dynamic CSS regeneration
 * 
 * Enfold compiles theme settings into dynamic CSS. This function
 * clears the relevant transients to force regeneration on next load.
 */
function enfold_gitops_regenerate_css() {
    // Delete Enfold's CSS transients
    delete_transient('avia_dynamic_stylesheet');
    delete_transient('avia_stylesheet_compiled');
    delete_transient('avia_stylesheet_dynamic_');  // Prefix for variations
    
    // Delete any cached CSS files
    global $wpdb;
    $wpdb->query(
        "DELETE FROM {$wpdb->options} 
         WHERE option_name LIKE '_transient_avia_%' 
         OR option_name LIKE '_transient_timeout_avia_%'"
    );
    
    // If Enfold's avia_superobject class exists, use its method
    if (class_exists('avia_superobject') && method_exists('avia_superobject', 'reset_all_options')) {
        // This is the nuclear option - only use if needed
        // avia_superobject::reset_all_options();
    }
}

/**
 * Clear WordPress and common caching plugin caches
 */
function enfold_gitops_clear_caches() {
    // WordPress object cache
    if (function_exists('wp_cache_flush')) {
        wp_cache_flush();
    }
    
    // WP Super Cache
    if (function_exists('wp_cache_clear_cache')) {
        wp_cache_clear_cache();
    }
    
    // W3 Total Cache
    if (function_exists('w3tc_flush_all')) {
        w3tc_flush_all();
    }
    
    // SiteGround Optimizer
    if (function_exists('sg_cachepress_purge_cache')) {
        sg_cachepress_purge_cache();
    }
    
    // LiteSpeed Cache
    if (class_exists('LiteSpeed_Cache_API') && method_exists('LiteSpeed_Cache_API', 'purge_all')) {
        LiteSpeed_Cache_API::purge_all();
    }
    
    // WP Rocket
    if (function_exists('rocket_clean_domain')) {
        rocket_clean_domain();
    }
}

/**
 * Add admin notice about GitOps features
 */
add_action('admin_notices', function() {
    $screen = get_current_screen();
    if ($screen && $screen->id === 'plugins') {
        ?>
        <div class="notice notice-info is-dismissible">
            <p>
                <strong>Enfold REST API Meta Support:</strong> 
                GitOps deployment active. Theme settings and page content can be managed via the REST API.
                <a href="https://github.com/tuvens/vibing-enfold" target="_blank">View documentation</a>
            </p>
        </div>
        <?php
    }
});
