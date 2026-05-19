#!/bin/sh

set -eu

REPO="${CODEX_FORK_REPO:-boopdotpng/codex}"
VERSION="${CODEX_FORK_VERSION:-latest}"
INSTALL_ROOT="${CODEX_FORK_INSTALL_ROOT:-$HOME/.local/share/boop-codex}"
BIN_DIR="$INSTALL_ROOT/bin"
BIN_PATH="$BIN_DIR/codex"
PROFILE="${CODEX_FORK_SHELL_PROFILE:-}"
LOCAL_BINARY=""
TMP_DIR=""

step() {
  printf '==> %s\n' "$1"
}

usage() {
  cat <<EOF
Usage: install.sh [--version TAG] [--repo OWNER/REPO] [--install-root PATH] [--shell-profile PATH]
       install.sh --local-binary PATH

Installs the boop Codex fork and adds a managed shell alias:
  alias codex="$BIN_PATH"
EOF
}

download_file() {
  url="$1"
  output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$output"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -q -O "$output" "$url"
    return
  fi

  echo "curl or wget is required." >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required." >&2
    exit 1
  fi
}

pick_target() {
  case "$(uname -s)" in
    Darwin)
      os="apple-darwin"
      ;;
    Linux)
      os="unknown-linux-musl"
      ;;
    *)
      echo "Unsupported OS: $(uname -s)" >&2
      exit 1
      ;;
  esac

  case "$(uname -m)" in
    arm64 | aarch64)
      arch="aarch64"
      ;;
    x86_64 | amd64)
      arch="x86_64"
      ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac

  printf '%s-%s\n' "$arch" "$os"
}

pick_profile() {
  if [ -n "$PROFILE" ]; then
    printf '%s\n' "$PROFILE"
    return
  fi

  case "${SHELL:-}" in
    */zsh)
      printf '%s\n' "$HOME/.zshrc"
      ;;
    */bash)
      printf '%s\n' "$HOME/.bashrc"
      ;;
    *)
      if [ -f "$HOME/.zshrc" ]; then
        printf '%s\n' "$HOME/.zshrc"
      else
        printf '%s\n' "$HOME/.bashrc"
      fi
      ;;
  esac
}

asset_url() {
  target="$1"
  asset="codex-$target.tar.gz"

  if [ "$VERSION" = "latest" ]; then
    printf 'https://github.com/%s/releases/latest/download/%s\n' "$REPO" "$asset"
  else
    printf 'https://github.com/%s/releases/download/%s/%s\n' "$REPO" "$VERSION" "$asset"
  fi
}

install_archive() {
  archive="$1"
  extract_dir="$TMP_DIR/extract"

  mkdir -p "$extract_dir" "$BIN_DIR"
  tar -xzf "$archive" -C "$extract_dir"

  candidate=""
  for path in \
    "$extract_dir/codex" \
    "$extract_dir/bin/codex" \
    "$extract_dir/package/codex" \
    "$extract_dir/package/bin/codex"
  do
    if [ -f "$path" ]; then
      candidate="$path"
      break
    fi
  done

  if [ -z "$candidate" ]; then
    echo "Release archive did not contain a codex binary." >&2
    exit 1
  fi

  cp "$candidate" "$BIN_PATH"
  chmod 0755 "$BIN_PATH"
}

install_local_binary() {
  local_binary="$1"

  if [ ! -f "$local_binary" ]; then
    echo "Local binary does not exist: $local_binary" >&2
    exit 1
  fi

  mkdir -p "$BIN_DIR"
  cp "$local_binary" "$BIN_PATH"
  chmod 0755 "$BIN_PATH"
}

write_alias_block() {
  profile="$1"
  begin="# >>> boop codex fork >>>"
  end="# <<< boop codex fork <<<"
  alias_line="alias codex=\"$BIN_PATH\""
  tmp_profile="$TMP_DIR/profile"

  mkdir -p "$(dirname "$profile")"
  touch "$profile"

  awk -v begin="$begin" -v end="$end" -v alias_line="$alias_line" '
    BEGIN {
      in_block = 0
      wrote = 0
    }
    $0 == begin {
      if (!wrote) {
        print begin
        print alias_line
        print end
        wrote = 1
      }
      in_block = 1
      next
    }
    in_block {
      if ($0 == end) {
        in_block = 0
      }
      next
    }
    {
      print
    }
    END {
      if (!wrote) {
        print ""
        print begin
        print alias_line
        print end
      }
    }
  ' "$profile" >"$tmp_profile"

  mv "$tmp_profile" "$profile"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      [ "$#" -ge 2 ] || { echo "--version requires a value." >&2; exit 1; }
      VERSION="$2"
      shift
      ;;
    --repo)
      [ "$#" -ge 2 ] || { echo "--repo requires a value." >&2; exit 1; }
      REPO="$2"
      shift
      ;;
    --install-root)
      [ "$#" -ge 2 ] || { echo "--install-root requires a value." >&2; exit 1; }
      INSTALL_ROOT="$2"
      BIN_DIR="$INSTALL_ROOT/bin"
      BIN_PATH="$BIN_DIR/codex"
      shift
      ;;
    --shell-profile)
      [ "$#" -ge 2 ] || { echo "--shell-profile requires a value." >&2; exit 1; }
      PROFILE="$2"
      shift
      ;;
    --local-binary)
      [ "$#" -ge 2 ] || { echo "--local-binary requires a value." >&2; exit 1; }
      LOCAL_BINARY="$2"
      shift
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

require_command mktemp
require_command tar

target="$(pick_target)"
url="$(asset_url "$target")"
profile="$(pick_profile)"

TMP_DIR="$(mktemp -d)"
cleanup() {
  if [ -n "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT INT TERM

step "Installing to $BIN_PATH"
if [ -n "$LOCAL_BINARY" ]; then
  install_local_binary "$LOCAL_BINARY"
else
  step "Downloading $url"
  download_file "$url" "$TMP_DIR/codex.tar.gz"
  install_archive "$TMP_DIR/codex.tar.gz"
fi

step "Updating alias in $profile"
write_alias_block "$profile"

"$BIN_PATH" --version >/dev/null
printf 'Installed boop Codex fork at %s\n' "$BIN_PATH"
printf 'Restart your shell or run: . %s\n' "$profile"
