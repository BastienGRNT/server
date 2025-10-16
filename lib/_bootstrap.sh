#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s lastpipe

if [[ -z "${ROOT_DIR:-}" ]]; then
  ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd -P)"
fi
LIB_DIR="$ROOT_DIR/lib"

import() {
  local file="$1" path="$LIB_DIR/$file"
  [[ -f "$path" ]] || { echo "❌ import: $path introuvable" >&2; exit 1; }
  local guard="__IMPORT__${file//[^a-zA-Z0-9]/_}"
  [[ "${!guard:-0}" -eq 1 ]] && return 0
  declare -g "$guard"=1
  # shellcheck source=/dev/null
  source "$path"
}

__on_error() {
  local exit_code=$? line="${BASH_LINENO[0]:-?}" src="${BASH_SOURCE[1]:-main}"
  echo "💥 Erreur (code $exit_code) à la ligne $line dans $src" >&2
  exit "$exit_code"
}
trap __on_error ERR
