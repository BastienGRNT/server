#!/usr/bin/env bash
[[ "${__UTIL_SH__:-0}" -eq 1 ]] && return; __UTIL_SH__=1
import "log.sh"

util::require_root(){ [[ $EUID -eq 0 ]] || { log::err "Exécute en root (sudo)."; exit 1; }; }
util::ensure_dir(){ install -d -m "${2:-755}" "$1"; }

util::write_file(){ # util::write_file <path> <mode> <content>
  local path="$1" mode="$2"; shift 2
  install -D -m "$mode" /dev/null "$path"
  printf "%s" "$*" > "$path"
}

util::heredoc(){ # util::heredoc <path> <mode>
  local path="$1" mode="$2"
  install -D -m "$mode" /dev/null "$path"
  cat > "$path"
}

util::is_systemd(){ command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; }

# Affichage simple en "table"
util::kv(){
  # util::kv "Clé" "Valeur"
  printf "  %-20s : %s\n" "$1" "$2"
}
