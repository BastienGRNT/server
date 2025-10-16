#!/usr/bin/env bash
[[ "${__LOG_SH__:-0}" -eq 1 ]] && return; __LOG_SH__=1

# log::init <level> <no_color> <ts> <theme> <tag>
log::init(){
  LOG_LEVEL="${1:-${LOG_LEVEL:-info}}"
  NO_COLOR="${2:-${NO_COLOR:-0}}"
  LOG_TS="${3:-${LOG_TS:-1}}"
  LOG_THEME="${4:-${LOG_THEME:-emoji}}"
  LOG_TAG="${5:-${LOG_TAG:-app}}"

  declare -gA __LOG_LVL_NUM=( [debug]=10 [info]=20 [warn]=30 [error]=40 [silent]=99 )
  __LOG_CUR_LVL=${__LOG_LVL_NUM[$LOG_LEVEL]:-20}

  if [[ -t 1 && "$NO_COLOR" != "1" ]]; then
    c_reset="\033[0m"; c_dim="\033[2m"; c_bold="\033[1m"
    c_blue="\033[34m"; c_green="\033[32m"; c_yellow="\033[33m"; c_red="\033[31m"
  else
    c_reset=""; c_dim=""; c_bold=""; c_blue=""; c_green=""; c_yellow=""; c_red=""
  fi

  case "$LOG_THEME" in
    emoji)  ICON_INFO="•"; ICON_OK="✓"; ICON_WARN="!"; ICON_ERR="✗";;
    minimal)ICON_INFO="-"; ICON_OK="+"; ICON_WARN="!"; ICON_ERR="x";;
    plain)  ICON_INFO="INFO"; ICON_OK="OK"; ICON_WARN="WARN"; ICON_ERR="ERR";;
    json)   ICON_INFO="info"; ICON_OK="ok"; ICON_WARN="warn"; ICON_ERR="error";;
    *)      ICON_INFO="•"; ICON_OK="✓"; ICON_WARN="!"; ICON_ERR="✗";;
  esac
}

log::set_level(){ __LOG_CUR_LVL=${__LOG_LVL_NUM[$1]:-20}; }
log::ts(){ [[ "${LOG_TS:-1}" == "1" ]] && date +"%Y-%m-%d %H:%M:%S" || printf ""; }

log::__emit(){
  local level="$1" icon="$2" color="$3"; shift 3
  local ts; ts="$(log::ts)"
  if [[ "$LOG_THEME" == "json" ]]; then
    # JSON line (uncolored)
    printf '{"ts":"%s","tag":"%s","level":"%s","msg":"%s"}\n' "${ts}" "${LOG_TAG}" "${level}" "$(printf "%s" "$*" | sed 's/"/\\"/g')"
  else
    [[ -n "$ts" ]] && ts="$ts  "
    printf "%b%s[%s] %b%s%b %s\n" "$c_dim" "$ts" "$LOG_TAG" "$c_reset" "${color}${icon}${c_reset}" "$c_dim" "$*"
  fi
}

log::__should(){ local want=${__LOG_LVL_NUM[$1]:-20}; [[ $want -ge $__LOG_CUR_LVL ]]; }

log::debug(){ log::__should debug && log::__emit debug "$ICON_INFO" "$c_blue" "$*"; }
log::info() { log::__should info  && log::__emit info  "$ICON_INFO" "$c_blue" "$*"; }
log::ok()   { log::__should info  && log::__emit info  "$ICON_OK"   "$c_green" "$*"; }
log::warn() { log::__should warn  && log::__emit warn  "$ICON_WARN" "$c_yellow" "$*"; }
log::err()  { log::__should error && log::__emit error "$ICON_ERR"  "$c_red" "$*"; }

log::hr()      { log::__should info && printf "%b%s%b\n" "$c_dim" "$(printf '─%.0s' {1..70})" "$c_reset"; }
log::banner(){ log::hr; printf "%b%s%b\n" "$c_bold" "$*" "$c_reset"; log::hr; }
log::step(){   __LOG_STEP=$(( ${__LOG_STEP:-0} + 1 )); log::__should info && log::__emit info "#${__LOG_STEP}" "$c_blue" "$*"; }

# Tee vers fichier (append) — conserve l’affichage à l’écran
log::tee(){
  local file="$1"; mkdir -p "$(dirname "$file")"
  exec > >(tee -a "$file") 2>&1
  log::info "Logs redirigés vers $file"
}
