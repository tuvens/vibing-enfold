# vibing-enfold

GitOps template for WordPress sites using the Enfold theme. Manage your content via Git with automatic deployment through GitHub Actions.

## Features

- **Git-based content management** - Edit Enfold pages as text files
- **Automatic deployment** - Push to deploy via GitHub Actions
- **AI-powered editing** - Claude Code plugin with `/wp-` slash commands
- **Multi-environment support** - Staging and production branches
- **Theme customization** - Design tokens for colors, fonts, and branding

## Quick Start

### 1. Create Your Repository

Click **"Use this template"** → **"Create a new repository"**

### 2. Clone with Submodules

```bash
git clone --recurse-submodules https://github.com/YOUR-USERNAME/YOUR-REPO.git
cd YOUR-REPO
```

### 3. Configure WordPress Connection

Create `.claude-wp.json` from the example:

```bash
cp .claude-wp.json.example .claude-wp.json
```

Edit with your WordPress URLs:

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

### 4. Add GitHub Secrets

In your repo: **Settings → Secrets → Actions**

| Secret | Value |
|--------|-------|
| `USERNAME` | Your WordPress username |
| `APP_PASSWORD` | WordPress Application Password |

**To create an Application Password:**
1. WordPress Admin → Users → Profile
2. Scroll to "Application Passwords"
3. Add new password named "GitHub Actions"

### 5. Install WordPress Plugin

Upload `wordpress/plugins/enfold-rest-meta/` to your WordPress site:

```
wp-content/plugins/enfold-rest-meta/
├── enfold-rest-meta.php
└── README.md
```

Activate the plugin in WordPress Admin.

### 6. Start Using

**With Claude Code:**
```
/wp-status           # Check connection
/wp-pull-pages       # Import existing content
/wp-create-page      # Create a new page
```

**Manual:**
```bash
# Edit content
vim content/pages/about.txt

# Deploy
git add content/pages/about.txt
git commit -m "Update about page"
git push origin staging
```

## Repository Structure

```
├── .claude/plugins/enfold-llm/  # Claude Code plugin (submodule)
├── .github/
│   ├── workflows/deploy.yml      # Deployment automation
│   └── dependabot.yml            # Plugin updates
├── content/                       # Page content (Enfold shortcodes)
│   ├── pages/
│   ├── posts/
│   ├── portfolio/
│   └── layouts/
├── meta/                          # WordPress IDs (auto-generated)
├── scripts/                       # Deployment utilities
├── theme/
│   └── design-tokens.json         # Site branding
├── wordpress/plugins/             # WP plugin to install
├── CLAUDE.md                      # Claude Code instructions
└── README.md                      # This file
```

## Branches & Environments

| Branch | Deploys To | Purpose |
|--------|------------|---------|
| `staging` | Staging site | Test changes first |
| `main` | Production site | Live website |

**Workflow:** Edit on `staging` → Test → Merge to `main`

## Content File Format

### New Pages (YAML frontmatter)

```txt
---
title: About Us
slug: about
status: publish
---
[av_section]
[av_one_full first]
[av_heading heading='About Us' tag='h1'][/av_heading]
[av_textblock]<p>Your content here.</p>[/av_textblock]
[/av_one_full]
[/av_section]
```

### Existing Pages (shortcodes only)

After initial creation, pages are tracked by `meta/pages/*.json` files containing WordPress IDs.

## Theme Customization

Edit `theme/design-tokens.json` to customize your site:

```json
{
  "brand": {
    "name": "My Site",
    "tagline": "Welcome to my website"
  },
  "colors": {
    "primary": "#3498db",
    "secondary": "#2c3e50"
  },
  "typography": {
    "heading_font": "Montserrat:400,700",
    "body_font": "Open Sans:400,400i,700"
  }
}
```

Push to deploy theme changes.

## Claude Code Commands

The included plugin provides these slash commands:

| Command | Description |
|---------|-------------|
| `/wp-setup` | Interactive setup wizard |
| `/wp-status` | Check WordPress connection |
| `/wp-create-page` | Create a new page |
| `/wp-update-page` | Update existing page |
| `/wp-pull-pages` | Import pages from WordPress |
| `/wp-deploy-theme` | Deploy theme settings |

## Importing Existing Content

If you have an existing Enfold site:

```bash
# Set credentials
export WP_USERNAME='your-username'
export WP_APP_PASSWORD='your-app-password'
export WP_BASE_URL='https://your-site.com'

# Pull all pages
./scripts/bulk-import.sh pages

# Or pull specific page by ID
./scripts/pull-content.sh page 123 about
```

## Troubleshooting

**Deployment not triggering?**
- Only changes to `content/**` trigger deploys
- Check GitHub Actions tab for errors

**401 Unauthorized?**
- Verify GitHub Secrets are set correctly
- Check Application Password hasn't expired

**Shortcodes appearing as text?**
- Ensure Enfold REST Meta plugin is active
- Clear any caching plugins

**Need more help?**
- See `CLAUDE.md` for Claude Code troubleshooting
- Check `wordpress/plugins/enfold-rest-meta/README.md`

## Requirements

- WordPress 5.6+ with Enfold theme
- GitHub account
- (Optional) Claude Code for AI-assisted editing

## License

MIT

## Credits

Built with [enfold-llm](https://github.com/tuvens/enfold-llm) plugin for Claude Code.
