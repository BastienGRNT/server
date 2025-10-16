#!/usr/bin/env bash
# run.sh — helpers d'exécution

[[ "${__RUN_SH__:-0}" -eq 1 ]] && return; __RUN_SH__=1
import "log.sh"

run::exec_show(){
  local cmd="${1:-}"; [[ -n "$cmd" ]] || { log::error "exec_show: commande vide"; return 1; }
  local cwd="${2:-}"
  log::info "run: $cmd"
  if [[ -n "$cwd" ]]; then ( cd "$cwd" && bash -lc "$cmd" ); else bash -lc "$cmd"; fi
}

run::exec_quiet(){
  local cmd="${1:-}"; [[ -n "$cmd" ]] || { log::error "exec_quiet: commande vide"; return 1; }
  local cwd="${2:-}"
  log::debug "run-quiet: $cmd"
  if [[ -n "$cwd" ]]; then
    if [[ -n "${LOG_FILE:-}" ]]; then ( cd "$cwd" && bash -lc "$cmd" ) >>"$LOG_FILE" 2>&1
    else ( cd "$cwd" && bash -lc "$cmd" ) >/dev/null 2>&1; fi
  else
    if [[ -n "${LOG_FILE:-}" ]]; then bash -lc "$cmd" >>"$LOG_FILE" 2>&1
    else bash -lc "$cmd" >/dev/null 2>&1; fi
  fi
}
