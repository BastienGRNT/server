#!/usr/bin/env bash
# log.sh — logging simple + rotation

[[ "${__LOG_SH__:-0}" -eq 1 ]] && return; __LOG_SH__=1

log::init() {
  LOG_LEVEL="${1:-${LOG_LEVEL:-info}}"        # debug|info|warn|error|silent
  LOG_FILE="${2:-${LOG_FILE:-}}"
  LOG_MAX_SIZE="${3:-${LOG_MAX_SIZE:-1048576}}"
  LOG_BACKUPS="${4:-${LOG_BACKUPS:-5}}"
  declare -gA __LOG_NUM=( [debug]=10 [info]=20 [warn]=30 [error]=40 [silent]=99 )
  __LOG_CUR="${__LOG_NUM[$LOG_LEVEL]:-20}"
  if [[ -n "$LOG_FILE" ]]; then
    mkdir -p "$(dirname "$LOG_FILE")"
  fi
}

log::rotate() {
  [[ -n "${LOG_FILE:-}" && -f "$LOG_FILE" ]] || return 0
  local size; size=$(wc -c < "$LOG_FILE" || echo 0)
  (( size <= LOG_MAX_SIZE )) && return 0
  local i; for (( i=LOG_BACKUPS-1; i>=1; i-- )); do
    [[ -f "${LOG_FILE}.${i}" ]] && mv -f "${LOG_FILE}.${i}" "${LOG_FILE}.$((i+1))"
  done
  cp -f "$LOG_FILE" "${LOG_FILE}.1"
  : > "$LOG_FILE"
}

log::__should(){ local want=${__LOG_NUM[$1]:-20}; [[ $want -ge $__LOG_CUR ]]; }
log::__emit(){
  local level="$1"; shift
  local ts; ts="$(date +"%Y-%m-%d %H:%M:%S")"
  local line="[$ts] [$level] $*"
  log::__should "$level" && echo "$line"
  if [[ -n "${LOG_FILE:-}" ]]; then
    log::rotate; echo "$line" >> "$LOG_FILE"
  fi
}

log::debug(){ log::__emit debug "$*"; }
log::info(){  log::__emit info  "$*"; }
log::warn(){  log::__emit warn  "$*"; }
log::error(){ log::__emit error "$*"; }
log::clear(){ [[ -n "${LOG_FILE:-}" ]] && : > "$LOG_FILE"; }
log::ok(){ log::__emit info "$*"; }  # alias pour compat
log::err(){ log::__emit error "$*"; } # alias pour compat
