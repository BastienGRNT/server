#!/usr/bin/env bash
# _bootstrap.sh — loader + strict mode
set -Eeuo pipefail
shopt -s lastpipe

if [[ -z "${ROOT_DIR:-}" ]]; then
  ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd -P)"
fi
LIB_DIR="${LIB_DIR:-$ROOT_DIR/lib}"

import() {
  local file="${1:-}"; [[ -n "$file" ]] || { echo "import: argument manquant" >&2; exit 1; }
  local path="$LIB_DIR/$file"; [[ -f "$path" ]] || { echo "import: $path introuvable" >&2; exit 1; }
  local guard="__IMPORT__${file//[^a-zA-Z0-9]/_}"
  [[ "${!guard:-0}" -eq 1 ]] && return 0
  declare -g "$guard"=1
  # shellcheck source=/dev/null
  source "$path"
}

__on_error() {
  local code=$? line="${BASH_LINENO[0]:-?}" src="${BASH_SOURCE[1]:-main}"
  echo "Erreur (code $code) à la ligne $line dans $src" >&2
  exit "$code"
}
trap __on_error ERR
