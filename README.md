# LaserSell APT Repository

[![GitHub Pages Status](https://github.com/lasersell/apt/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/lasersell/apt/actions/workflows/pages/pages-build-deployment)
[![Website Up](https://img.shields.io/website?url=https%3A%2F%2Fdl.lasersell.io%2Flasersell.asc&label=apt-repo&up_message=online&down_message=offline)](https://dl.lasersell.io/)
[![Version](https://img.shields.io/badge/version-0.1.3-blue)](https://dl.lasersell.io/pool/main/l/lasersell/)
[![Platform](https://img.shields.io/badge/platform-linux--amd64%2Farm64%20%2B%20macos-lightgrey)](https://dl.lasersell.io/)
[![License](https://img.shields.io/badge/license-Proprietary-red)](https://dl.lasersell.io/LICENSE)

## Quick install (recommended)

```sh
curl -fsSL https://dl.lasersell.io/install.sh | bash
```

This repository hosts the LaserSell APT package repository (served via GitHub Pages), plus multi-platform binaries.

## Linux (Debian/Ubuntu/WSL) via install.sh

```sh
curl -fsSL https://dl.lasersell.io/install.sh | bash
```

## Linux (Debian/Ubuntu/WSL) without install.sh (manual APT)

```sh
curl -fsSL https://dl.lasersell.io/lasersell.asc | sudo gpg --dearmor -o /usr/share/keyrings/lasersell-archive-keyring.gpg
ARCH="$(dpkg --print-architecture)"
echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/lasersell-archive-keyring.gpg] https://dl.lasersell.io stable main" | sudo tee /etc/apt/sources.list.d/lasersell.list > /dev/null
sudo apt update
sudo apt install lasersell
```

## macOS via install.sh

```sh
curl -fsSL https://dl.lasersell.io/install.sh | bash
```

## macOS via Homebrew

```sh
brew tap lasersell/lasersell
brew install lasersell
```

## macOS without Homebrew (tarball)

```sh
curl -fsSL https://dl.lasersell.io/install.sh | bash -s -- --method tar
```

## Windows (via WSL)

1) Install WSL (Windows Terminal or PowerShell as Administrator):

```powershell
wsl --install
```

2) Restart your computer, then open your WSL Linux distro:
   - Start menu → search for your distro name (e.g., “Ubuntu”) → open it, or
   - Windows Terminal / PowerShell → run `wsl` to launch the default distro.

Then run:

```sh
curl -fsSL https://dl.lasersell.io/install.sh | bash
```

## Upgrade / Uninstall

- APT: `sudo apt update && sudo apt install lasersell`
- Homebrew: `brew upgrade lasersell`
- Tarball install: re-run `install.sh` (it overwrites the binary). To uninstall, remove the installed `lasersell` binary from your prefix.

LaserSell software is proprietary and requires a valid commercial license to use.
