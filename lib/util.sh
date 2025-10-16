#!/usr/bin/env bash
# util.sh — utilitaires

[[ "${__UTIL_SH__:-0}" -eq 1 ]] && return; __UTIL_SH__=1
import "log.sh"

util::require_root(){ [[ $EUID -eq 0 ]] || { log::error "Exécuter en root (sudo)."; exit 1; }; }
util::ensure_dir(){ install -d -m "${2:-755}" "$1"; }

util::write_atomic(){ # <path> <mode> <content...>
  local path="$1" mode="$2"; shift 2
  local tmp; tmp="$(mktemp)"; printf "%s" "$*" > "$tmp"; install -D -m "$mode" "$tmp" "$path"; rm -f "$tmp"
}

util::heredoc_atomic(){ # <path> <mode>
  local path="$1" mode="$2" tmp; tmp="$(mktemp)"; cat > "$tmp"; install -D -m "$mode" "$tmp" "$path"; rm -f "$tmp"
}

util::env_set(){ # <file> <KEY> <VALUE>
  local file="$1" key="$2" val="$3"
  [[ -f "$file" ]] || : > "$file"
  awk -v k="$key" -v v="$val" '
    BEGIN{found=0}
    $0 ~ "^"k"=" {print k"="v; found=1; next}
    {print}
    END{ if(!found) print k"="v }
  ' "$file" > "${file}.tmp" && mv -f "${file}.tmp" "$file"
}

util::kv(){ printf "  %-15s : %s\n" "$1" "$2"; }
