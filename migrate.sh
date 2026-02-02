#!/usr/bin/env bash
set -euo pipefail

OLD_REPO="https://lasersell.github.io/apt"
NEW_REPO="https://dl.lasersell.io"
LIST_FILE="/etc/apt/sources.list.d/lasersell.list"
KEYRING="/usr/share/keyrings/lasersell-archive-keyring.gpg"

RESET=""
BOLD=""
DIM=""
RED=""
GREEN=""
YELLOW=""
BLUE=""
CYAN=""
ACCENT=""

init_colors() {
  local use_color=1

  if [ -n "${NO_COLOR:-}" ]; then
    use_color=0
  elif [ "${TERM:-}" = "dumb" ]; then
    use_color=0
  fi

  if [ "${use_color}" -eq 1 ]; then
    RESET=$'\033[0m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RED=$'\033[31m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    BLUE=$'\033[34m'
    CYAN=$'\033[36m'
    ACCENT="${CYAN}"
  else
    RESET=""
    BOLD=""
    DIM=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    ACCENT=""
  fi
}

title() { printf '%b\n' "${BOLD}${ACCENT}$*${RESET}"; }
step() { printf '%b\n' "${BOLD}➜${RESET} $*"; }
info() { printf '%b\n' "${BLUE}ℹ️${RESET} $*"; }
warn() { printf '%b\n' "${YELLOW}⚠️${RESET} $*"; }
ok() { printf '%b\n' "${GREEN}✅${RESET} $*"; }
err() { printf '%b\n' "${RED}❌${RESET} $*" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "missing required command: $1"; exit 1; }
}

sudo_prefix() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo ""
  else
    command -v sudo >/dev/null 2>&1 || { err "sudo is required"; exit 1; }
    echo "sudo"
  fi
}

remove_old_repo_lines() {
  local sudo_cmd="$1"

  if [ -f /etc/apt/sources.list ] && grep -q "${OLD_REPO}" /etc/apt/sources.list; then
    ${sudo_cmd} sed -i.bak "/${OLD_REPO//\//\\/}/d" /etc/apt/sources.list
    ok "Removed old repo lines from /etc/apt/sources.list (backup: /etc/apt/sources.list.bak)."
  fi

  if [ -f "${LIST_FILE}" ] && grep -q "${OLD_REPO}" "${LIST_FILE}"; then
    ${sudo_cmd} rm -f "${LIST_FILE}"
    ok "Removed ${LIST_FILE}."
  fi

  if [ -d /etc/apt/sources.list.d ]; then
    for f in /etc/apt/sources.list.d/*.list; do
      [ -e "$f" ] || continue
      if grep -q "${OLD_REPO}" "$f"; then
        ${sudo_cmd} rm -f "$f"
        ok "Removed $f."
      fi
    done
  fi
}

main() {
  init_colors
  title "🚀 LaserSell migration"
  info "This will remove the old repo and reinstall from ${NEW_REPO}"

  need_cmd curl
  need_cmd apt-get

  local sudo_cmd
  sudo_cmd="$(sudo_prefix)"

  step "🧹 Removing old LaserSell APT repo entries (${OLD_REPO})..."
  remove_old_repo_lines "${sudo_cmd}"

  step "🔄 Refreshing apt index..."
  ${sudo_cmd} apt-get update -y

  step "⚡ Installing with quick command..."
  info "curl -fsSL ${NEW_REPO}/install.sh | bash"
  curl -fsSL "${NEW_REPO}/install.sh" | bash

  ok "Done."
  info "If you need to re-add the key manually later, it will be at ${KEYRING}."
}

main "$@"
