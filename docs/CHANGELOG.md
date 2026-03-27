# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.1.1] - 2026-03-27

### Added
- Architecture diagrams (SVG) for all 4 languages (EN, KO, ZH, JA) with new "Architecture" section in each README

### Changed
- Reorganized project file structure into `assets/`, `docs/`, and `docs/images/` directories
  - Images and SVGs → `assets/`
  - Beginner's guides and CHANGELOG → `docs/`
  - Guide screenshots → `docs/images/` (previously `guide_images/`)
- Updated all internal references (image paths, guide links) across READMEs and guide files

## [1.1.0] - 2026-03-26

### Added
- `.env` file as a single source of truth for user configuration (`CLAW_USER`, `CLAW_PASSWORD`)
- Dynamic user creation at container startup — custom usernames now work without rebuild issues
- Runtime password synchronization — password changes take effect without rebuilding the image
- User config templates saved to `/opt/openclaw-defaults/` for new user initialization

### Changed
- `docker-compose.yml` now references `.env` variables (`${CLAW_USER}`, `${CLAW_PASSWORD}`) for environment and volume path
- `entrypoint.sh` creates the Linux user dynamically if it doesn't exist, copies default configs, and syncs password on every start
- Updated all README files (EN, KO, ZH, JA) with `.env` usage instructions, updated environment variable tables, and file structure
- Updated all Beginner's Guide files (EN, KO, ZH, JA) to mention `.env` for password customization

### Fixed
- Changing `USER` in docker-compose.yml no longer causes login failures (user is now created at runtime)
- Changing `PASSWORD` now applies to both VNC and RDP/sudo login (previously only VNC was updated at runtime)
- XFCE panels (menu bar, dock) now appear correctly for new users — system defaults are copied before wallpaper config to prevent XFCE from skipping first-run panel initialization

## [1.0.0] - 2026-03-25

### Added
- Initial Docker setup: Ubuntu 24.04 + XFCE4 + TigerVNC + NoVNC + xRDP
- Google Chrome with `--no-sandbox` wrapper as default browser
- Node.js 22 and OpenClaw pre-installed via npm
- OpenClaw Gateway auto-start in entrypoint
- Desktop shortcuts: OpenClaw Setup, Dashboard, Terminal
- Default `openclaw.json` config with Gateway on port 18789
- `xdg-open` wrapper to rewrite Docker internal IPs to localhost
- 3-tier VNC password fallback: `vncpasswd` binary, `openssl`, pure Python DES
- Desktop wallpaper auto-configuration for VNC and RDP monitors
- Data persistence via `openclaw-home` named volume
- Beginner's guides with screenshots in 4 languages (EN, KO, ZH, JA)
- README documentation in 4 languages (EN, KO, ZH, JA)
