#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://dl.lasersell.io"
BIN_BASE="${BASE_URL}/binaries/lasersell"

METHOD="auto"
VERSION=""
PREFIX=""
NO_COLOR_FLAG=0

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

  if [ "${NO_COLOR_FLAG}" -eq 1 ]; then
    use_color=0
  elif [ -n "${NO_COLOR:-}" ]; then
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
info() { printf '%b\n' "${BLUE}ℹ️ ${RESET}$*"; }
warn() { printf '%b\n' "${YELLOW}⚠️${RESET} $*"; }
ok() { printf '%b\n' "${GREEN}✅${RESET} $*"; }
success() { ok "$@"; }
err() { printf '%b\n' "${RED}❌${RESET} $*" >&2; }

die() {
  err "$*"
  exit 1
}

banner() {
  title "🚀 LaserSell Installer"
  info "Install the LaserSell CLI on 🪟 Windows (WSL), 🍎 macOS, 🐧 Linux, 🍓 Raspberry Pi (arm64)"
  printf '%b\n' "${DIM}${BASE_URL}${RESET}"
}

on_error() {
  local line="${1:-unknown}"
  err "Installer failed (line ${line})."
  info "Try re-running with: bash -x"
}

usage() {
  cat <<EOF
🚀 LaserSell installer

Usage:
  curl -fsSL ${BASE_URL}/install.sh | bash
  curl -fsSL ${BASE_URL}/install.sh | bash -s -- [options]

Options:
  --method auto|apt|brew|tar   Installation method (default: auto)
  --version X.Y.Z             Install a specific version (tar mode). If omitted, uses latest.txt.
  --prefix DIR                Install directory for tar mode (default: /usr/local/bin if writable, else ~/.local/bin)
  --no-color                  Disable ANSI colors
  -h, --help                  Show help
EOF
}

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"; }

sudo_prefix() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo ""
  else
    command -v sudo >/dev/null 2>&1 || die "sudo is required for this install method"
    echo "sudo"
  fi
}

detect_os() {
  local s
  s="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "$s" in
    linux) echo "linux" ;;
    darwin) echo "darwin" ;;
    *) die "unsupported OS: $(uname -s)" ;;
  esac
}

detect_arch() {
  local m
  m="$(uname -m)"
  case "$m" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l|armv6l|armhf)
      die "32-bit ARM is not supported. Please use a 64-bit OS (arm64/aarch64) on Raspberry Pi."
      ;;
    *) die "unsupported CPU arch: $m" ;;
  esac
}

is_wsl() {
  [ -r /proc/version ] && grep -qiE '(microsoft|wsl)' /proc/version
}

is_raspberry_pi() {
  local model=""
  if [ -r /proc/device-tree/model ]; then
    model="$(tr -d '\0' </proc/device-tree/model)"
  elif [ -r /sys/firmware/devicetree/base/model ]; then
    model="$(tr -d '\0' </sys/firmware/devicetree/base/model)"
  else
    return 1
  fi
  echo "${model}" | grep -qi "raspberry pi"
}

apt_repo_supports_arch() {
  local arch="$1"
  local url="${BASE_URL}/dists/stable/main/binary-${arch}/Packages.gz"

  need_cmd curl

  if curl -fsSLI "${url}" >/dev/null 2>&1; then
    return 0
  fi
  curl -fsSL "${url}" -o /dev/null >/dev/null 2>&1
}

install_via_apt() {
  local arch="$1"
  local sudo_cmd
  sudo_cmd="$(sudo_prefix)"

  need_cmd curl

  if ! command -v apt-get >/dev/null 2>&1; then
    die "apt-get not found (use --method tar instead)"
  fi

  info "Installing via APT (arch=${arch})"

  step "[1/5] Update apt index…"
  ${sudo_cmd} apt-get update -y
  ok "Apt index updated"

  step "[2/5] Install dependencies (curl, gnupg)…"
  ${sudo_cmd} apt-get install -y curl gnupg
  ok "Dependencies installed"

  step "[3/5] Add signing key 🔑"
  curl -fsSL "${BASE_URL}/KEY.gpg" | ${sudo_cmd} gpg --dearmor -o /usr/share/keyrings/lasersell-archive-keyring.gpg
  ok "Signing key added"

  step "[4/5] Add APT source 🧾"
  echo "deb [arch=${arch} signed-by=/usr/share/keyrings/lasersell-archive-keyring.gpg] ${BASE_URL} stable main" | ${sudo_cmd} tee /etc/apt/sources.list.d/lasersell.list >/dev/null
  ok "APT source added"

  step "[5/5] Install lasersell 📦"
  ${sudo_cmd} apt-get update -y
  ${sudo_cmd} apt-get install -y lasersell
  ok "Installed: $(command -v lasersell) ($(lasersell --version 2>/dev/null || true))"
}

pick_prefix() {
  local os="$1"
  if [ -n "${PREFIX}" ]; then
    echo "${PREFIX}"
    return
  fi
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "/usr/local/bin"
    return
  fi
  if [ -w "/usr/local/bin" ]; then
    echo "/usr/local/bin"
    return
  fi
  echo "${HOME}/.local/bin"
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    die "need sha256sum or shasum for checksum verification"
  fi
}

install_via_tar() {
  local os="$1"
  local arch="$2"
  local version="$3"

  need_cmd curl
  need_cmd tar

  info "Installing via tarball"

  step "[1/5] Resolve version 🔎"
  if [ -z "${version}" ]; then
    version="$(curl -fsSL "${BIN_BASE}/latest.txt" | tr -d ' \r\n')"
    [ -n "${version}" ] || die "could not resolve latest version"
    ok "Latest version ${version}"
  else
    ok "Using version ${version}"
  fi

  local filename="lasersell_${version}_${os}_${arch}.tar.gz"
  local url="${BIN_BASE}/${version}/${filename}"
  local sums_url="${BIN_BASE}/${version}/SHA256SUMS"

  step "[2/5] Download tarball ⬇️"
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' EXIT
  curl -fsSL "${url}" -o "${tmp}/${filename}"
  ok "Tarball downloaded"

  step "[3/5] Download SHA256SUMS 🧾"
  curl -fsSL "${sums_url}" -o "${tmp}/SHA256SUMS"
  ok "Checksums downloaded"

  step "[4/5] Verify checksum ✅"
  local expected
  expected="$(grep " ${filename}$" "${tmp}/SHA256SUMS" | awk '{print $1}' || true)"
  [ -n "${expected}" ] || die "checksum not found for ${filename}"

  local actual
  actual="$(sha256_file "${tmp}/${filename}")"
  [ "${actual}" = "${expected}" ] || die "checksum mismatch for ${filename}"
  ok "Checksum verified"

  step "[5/5] Extract & install 📦"
  tar -xzf "${tmp}/${filename}" -C "${tmp}"
  [ -f "${tmp}/lasersell" ] || die "tarball did not contain lasersell binary"

  chmod +x "${tmp}/lasersell"

  local dest
  dest="$(pick_prefix "${os}")"
  mkdir -p "${dest}"

  if [ -w "${dest}" ]; then
    install -m 0755 "${tmp}/lasersell" "${dest}/lasersell"
  else
    local sudo_cmd
    sudo_cmd="$(sudo_prefix)"
    ${sudo_cmd} install -m 0755 "${tmp}/lasersell" "${dest}/lasersell"
  fi
  ok "Installed: ${dest}/lasersell ($("${dest}/lasersell" --version 2>/dev/null || true))"

  printf '\n'
  title "Next steps"
  info "Run: lasersell --help"

  if ! echo ":$PATH:" | grep -q ":${dest}:"; then
    warn "${dest} is not on your PATH. Add this to your shell profile:"
    printf '  export PATH="%s:$PATH"\n' "${dest}"
  fi
}

install_via_brew() {
  need_cmd brew
  info "🍎 Using Homebrew"
  step "Install lasersell"
  brew install lasersell/lasersell/lasersell
  ok "Installed: $(command -v lasersell) ($(lasersell --version 2>/dev/null || true))"
}

init_colors

# arg parsing
while [ "${#}" -gt 0 ]; do
  case "$1" in
    --method) METHOD="${2:-}"; shift 2 ;;
    --version) VERSION="${2:-}"; shift 2 ;;
    --prefix) PREFIX="${2:-}"; shift 2 ;;
    --no-color) NO_COLOR_FLAG=1; init_colors; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) die "unknown arg: $1" ;;
  esac
done

trap 'on_error $LINENO' ERR

banner

OS="$(detect_os)"
ARCH="$(detect_arch)"

IS_WSL=0
IS_PI=0

if is_wsl; then
  IS_WSL=1
fi

if is_raspberry_pi; then
  IS_PI=1
fi

if [ "${IS_WSL}" -eq 1 ]; then
  info "🔍 Environment: 🪟 Windows (WSL) (${ARCH})"
elif [ "${OS}" = "darwin" ]; then
  info "🔍 Environment: 🍎 macOS (${ARCH})"
elif [ "${IS_PI}" -eq 1 ]; then
  info "🔍 Environment: 🍓 Raspberry Pi (${OS}/${ARCH})"
else
  info "🔍 Environment: 🐧 Linux (${ARCH})"
fi

case "${METHOD}" in
  auto)
    if [ "${OS}" = "linux" ]; then
      if command -v apt-get >/dev/null 2>&1; then
        if apt_repo_supports_arch "${ARCH}"; then
          step "Selecting install method: APT"
          install_via_apt "${ARCH}"
        else
          warn "APT repo doesn’t provide packages for ${ARCH} — using tarball install instead."
          step "Selecting install method: tarball"
          install_via_tar "${OS}" "${ARCH}" "${VERSION}"
        fi
      else
        step "Selecting install method: tarball"
        install_via_tar "${OS}" "${ARCH}" "${VERSION}"
      fi
    else
      if command -v brew >/dev/null 2>&1; then
        step "Selecting install method: Homebrew"
        install_via_brew
      else
        step "Selecting install method: tarball"
        install_via_tar "${OS}" "${ARCH}" "${VERSION}"
      fi
    fi
    ;;
  apt)
    [ "${OS}" = "linux" ] || die "--method apt only supported on Linux/WSL"
    if ! apt_repo_supports_arch "${ARCH}"; then
      die "APT packages are not available for ${ARCH}. Re-run with --method tar."
    fi
    step "Selecting install method: APT"
    install_via_apt "${ARCH}"
    ;;
  brew)
    [ "${OS}" = "darwin" ] || die "--method brew only supported on macOS"
    step "Selecting install method: Homebrew"
    install_via_brew
    ;;
  tar)
    step "Selecting install method: tarball"
    install_via_tar "${OS}" "${ARCH}" "${VERSION}"
    ;;
  *)
    die "invalid --method: ${METHOD}"
    ;;
esac
