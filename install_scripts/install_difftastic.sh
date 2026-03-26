#!/bin/sh
set -eu

BIN_DIR="${HOME}/.local/bin"

get_arch() {
  case "$(uname -m)" in
    x86_64|amd64)   echo "x86_64" ;;
    aarch64|arm64)   echo "aarch64" ;;
    *)               echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
  esac
}

get_os() {
  case "$(uname -s)" in
    Linux)  echo "unknown-linux-gnu" ;;
    Darwin) echo "apple-darwin" ;;
    *)      echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
  esac
}

main() {
  local arch os tag url tmp_dir
  arch="$(get_arch)"
  os="$(get_os)"

  # get latest release tag
  if command -v curl >/dev/null 2>&1; then
    tag=$(curl -sL "https://api.github.com/repos/Wilfred/difftastic/releases/latest" | grep '"tag_name"' | head -1 | cut -d'"' -f4)
  elif command -v wget >/dev/null 2>&1; then
    tag=$(wget -qO- "https://api.github.com/repos/Wilfred/difftastic/releases/latest" | grep '"tag_name"' | head -1 | cut -d'"' -f4)
  else
    echo "Error: need curl or wget" >&2
    exit 1
  fi

  url="https://github.com/Wilfred/difftastic/releases/download/${tag}/difft-${arch}-${os}.tar.gz"
  echo "Downloading difftastic ${tag} from ${url}"

  tmp_dir="$(mktemp -d)"
  if command -v curl >/dev/null 2>&1; then
    curl -sL "$url" | tar xz -C "$tmp_dir"
  else
    wget -qO- "$url" | tar xz -C "$tmp_dir"
  fi

  mkdir -p "$BIN_DIR"
  cp "$tmp_dir/difft" "$BIN_DIR/difft"
  chmod +x "$BIN_DIR/difft"
  rm -rf "$tmp_dir"

  echo "Installed difft to ${BIN_DIR}/difft"
}

main "$@"
