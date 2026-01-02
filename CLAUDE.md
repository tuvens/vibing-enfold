# CLAUDE.md - Instructions for Claude Code

This file provides context for Claude Code when working with this repository.

## First Time Setup

**New repository from template?** Run the setup wizard:

```
/wp-setup
```

This will guide you through:
1. Configuring WordPress URLs
2. Setting up GitHub Secrets
3. Installing the WordPress plugin
4. Optionally importing existing content

## Quick Reference

| Task | Command |
|------|---------|
| Check connection | `/wp-status` |
| Create a new page | `/wp-create-page` |
| Update a page | `/wp-update-page` |
| Pull existing content | `/wp-pull-pages` |
| Deploy theme settings | `/wp-deploy-theme` |

## Repository Purpose

This is a GitOps-managed WordPress site using the Enfold theme. Page content is stored as Enfold shortcodes in text files and automatically deployed to WordPress via GitHub Actions.

## Architecture

```
content/pages/*.txt  ──push──▶  GitHub Actions  ──REST──▶  WordPress
       │                              │
       │                              ▼
       │                     meta/pages/*.json
       │                     (auto-generated for new pages)
       │
New files → create-wordpress-resource.sh → Creates in WP
Existing → deploy-content.sh → Updates in WP
```

## Branches & Environments

| Branch | Purpose |
|--------|--------|
| `staging` | Test changes first |
| `main` | Production deployment |

**Always test on staging before merging to main!**

## File Structure

```
├── content/
│   ├── pages/          # Page content (Enfold shortcodes)
│   ├── posts/          # Blog posts
│   ├── portfolio/      # Portfolio items
│   └── layouts/        # Enfold layouts
├── meta/
│   └── pages/          # Page metadata with WordPress IDs
├── scripts/            # Deployment utilities
├── theme/
│   └── design-tokens.json  # Site branding
└── wordpress/plugins/  # WP plugin to install
```

## Content File Format

### New Pages (with YAML frontmatter)

```txt
---
title: Page Title
slug: page-slug
status: publish
---
[av_section]...[/av_section]
```

### Existing Pages (no frontmatter)

Just Enfold shortcode content. Metadata is in `meta/pages/<name>.json`.

## Common Tasks

### Create a New Page

```bash
cat > content/pages/new-page.txt << 'EOF'
---
title: New Page Title
slug: new-page
status: publish
---
[av_section]
[av_one_full first]
[av_heading heading='New Page' tag='h1'][/av_heading]
[av_textblock]<p>Content here.</p>[/av_textblock]
[/av_one_full]
[/av_section]
EOF

git add content/pages/new-page.txt
git commit -m "Add new page"
git push origin staging
```

### Edit an Existing Page

```bash
vim content/pages/about.txt
git add content/pages/about.txt
git commit -m "Update about page"
git push origin staging
```

### Deploy to Production

```bash
git checkout main
git merge staging
git push origin main
```

## Enfold Shortcode Basics

```
[av_section]           - Full-width container
  [av_one_full first]  - Column (first needs 'first' attribute)
    [av_heading]       - Heading element
    [av_textblock]     - Text content (can contain HTML)
    [av_button]        - Button element
  [/av_one_full]
[/av_section]
```

For complete reference, see the enfold-llm plugin documentation:
`.claude/plugins/enfold-llm/context/enfold-knowledge/`

## Configuration

Your site configuration is in `.claude-wp.json` (gitignored):

```json
{
  "production": {
    "url": "https://your-site.com",
    "branch": "main"
  },
  "staging": {
    "url": "https://staging.your-site.com",
    "branch": "staging"
  }
}
```

## GitHub Secrets Required

| Secret | Purpose |
|--------|--------|
| `USERNAME` | WordPress username |
| `APP_PASSWORD` | WordPress Application Password |

## Troubleshooting

**Workflow not triggering?**
- Only `content/**` changes trigger deploys
- Check GitHub Actions tab for errors

**401 error?**
- Check GitHub Secrets are set correctly
- Verify Application Password hasn't expired

**Shortcodes appearing as text?**
- Ensure Enfold REST Meta plugin is active
- Clear any caching plugins

**Need the WordPress plugin?**
- Copy from `wordpress/plugins/enfold-rest-meta/`
- Or run `/wp-setup` for guided installation
