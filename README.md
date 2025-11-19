# TrustArc Demo App Downloader

A lightweight CLI for downloading the TrustArc Mobile Consent demo applications straight from the private repository `trustarc/ccm-mobile-consent-test-apps`.

## Highlights

- **Secure Access** – validates your GitHub Personal Access Token and reuses it for cloning the private demo repo.
- **One-Step Download** – fetches the entire demo app collection into any folder you choose.
- **Clean Exit** – optional cleanup routine removes stored tokens and CLI config files when you are done testing.

## Installation

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh)"
```

> Need to bypass caches? Add `-H 'Cache-Control: no-cache'` to the curl command.

## Requirements

- macOS or Linux shell with `bash` or `zsh`
- `git`, `curl` (or `wget`) installed locally
- GitHub Personal Access Token with `repo` scope and access to `trustarc/ccm-mobile-consent-test-apps`

## Usage

1. Run `install.sh` with the command above.
2. Enter your GitHub Personal Access Token when prompted.
3. Choose from the menu:
   - `Download demo applications` – prompts for a destination folder (defaults to `./ccm-mobile-consent-test-apps`) and clones the repo with your token.
   - `Clean up` – removes the stored token and CLI config file from your machine.
   - `Exit` – closes the CLI, leaving the saved config untouched.

The download workflow automatically:

- Creates (or replaces) the destination directory.
- Clones `https://github.com/trustarc/ccm-mobile-consent-test-apps.git` using your PAT for authentication.
- Stores your preferred destination in `~/.trustarc-cli-config` for future runs.

## Cleanup Details

Selecting **Clean up** removes:

- `TRUSTARC_TOKEN` export block from your shell RC (`~/.zshrc`, `~/.bashrc`, etc.).
- The CLI config file `~/.trustarc-cli-config`.

Restart your terminal after cleaning up to ensure the token is cleared from your current environment.

## Troubleshooting

- **Token validation failed** – Double-check the PAT scopes (`repo`) and repository access, then re-run the installer.
- **Git is required** – Install via Homebrew (`brew install git`) or your Linux package manager.
- **Download directory already exists** – The CLI asks before deleting; respond `y` to grab a fresh copy or `n` to keep what you have.
- **Clone failed** – Usually indicates expired credentials or network issues; re-run the installer and provide a valid token.

## Support

- TrustArc Documentation: https://docs.trustarc.com
- GitHub Issues: https://github.com/trustarc-ci/trustarc-cli/issues

---

Copyright © 2024 TrustArc.
