#!/usr/bin/env bash
# ui.sh — UX terminal simple

[[ "${__UI_SH__:-0}" -eq 1 ]] && return; __UI_SH__=1

: "${UI_NO_COLOR:=0}"
: "${UI_ICONS:=ascii}"
__ui_is_tty=0
if [[ -t 1 ]]; then __ui_is_tty=1; fi

if [[ "$UI_NO_COLOR" = "1" || $__ui_is_tty -eq 0 ]]; then
  c_reset=""; c_bold=""; c_dim=""; c_ok=""; c_warn=""; c_err=""
else
  c_reset="\033[0m"; c_bold="\033[1m"; c_dim="\033[2m"
  c_ok="\033[32m"; c_warn="\033[33m"; c_err="\033[31m"
fi

if [[ "$UI_ICONS" = "unicode" && $__ui_is_tty -eq 1 ]]; then
  sym_info=".."; sym_ok="✓"; sym_warn="!"; sym_err="✗"
else
  sym_info=".."; sym_ok="OK"; sym_warn="WARN"; sym_err="ERR"
fi

UI__HEADER=""; UI__SECTION_OPEN=0; UI__H_LINES=0
UI__CUR_STEP_MSG=""; UI__CUR_STEP_OPEN=0; UI__PERSIST_COUNT=0

__ui_cr(){ printf "\r"; }
__ui_clr(){ printf "\033[2K"; }
__ui_nl(){ printf "\n"; }
__ui_hr(){ printf "%s" "$(printf '─%.0s' {1..70})"; }

ui::section_begin(){
  local idx="$1" total="$2" title="$3"
  [[ -z "$idx" || -z "$total" || -z "$title" ]] && { echo "ui::section_begin: arguments manquants" >&2; return 1; }
  UI__HEADER="[$idx/$total] $title"; UI__SECTION_OPEN=1; UI__CUR_STEP_OPEN=0; UI__PERSIST_COUNT=0
  if [[ $__ui_is_tty -eq 1 ]]; then
    printf "\033[2J\033[H"; printf "%b%s%b\n" "$c_bold" "$UI__HEADER" "$c_reset"; __ui_hr; __ui_nl; UI__H_LINES=2
  else
    echo "$UI__HEADER"; UI__H_LINES=0
  fi
}

ui::step_start(){
  local msg="$1"; [[ "$UI__SECTION_OPEN" -eq 1 ]] || { echo "ui::step_start: aucune section ouverte" >&2; return 1; }
  if [[ "$UI__CUR_STEP_OPEN" -eq 1 ]]; then __ui_cr; __ui_clr; fi
  UI__CUR_STEP_MSG="$msg"; UI__CUR_STEP_OPEN=1
  if [[ $__ui_is_tty -eq 1 ]]; then printf "  [%s] %s..." "$sym_info" "$msg"; else echo "[..] $msg..."; fi
}

__ui_step_finalize(){
  local label="$1" color="$2"; [[ "$UI__CUR_STEP_OPEN" -eq 1 ]] || return 0
  if [[ $__ui_is_tty -eq 1 ]]; then __ui_cr; __ui_clr; printf "  [%b%s%b] %s\n" "$color" "$label" "$c_reset" "$UI__CUR_STEP_MSG"
  else echo "[$label] $UI__CUR_STEP_MSG"; fi
  UI__CUR_STEP_OPEN=0; UI__PERSIST_COUNT=$((UI__PERSIST_COUNT+1)); UI__CUR_STEP_MSG=""
}
ui::step_ok(){   __ui_step_finalize "$sym_ok"   "$c_ok"; }
ui::step_warn(){ __ui_step_finalize "$sym_warn" "$c_warn"; }
ui::step_err(){  __ui_step_finalize "$sym_err"  "$c_err"; }

ui::clear_section(){
  if [[ $__ui_is_tty -eq 1 ]]; then printf "\033[H"; local i; for ((i=0; i<UI__H_LINES; i++)); do printf "\n"; done; printf "\033[0J"; fi
  UI__PERSIST_COUNT=0
}

ui::section_end(){
  if [[ "$UI__CUR_STEP_OPEN" -eq 1 ]]; then __ui_step_finalize "$sym_warn" "$c_warn"; fi
  UI__SECTION_OPEN=0; __ui_nl
}

ui::title(){ local t="$1"; if [[ $__ui_is_tty -eq 1 ]]; then printf "%b%s%b\n" "$c_bold" "$t" "$c_reset"; else echo "$t"; fi }
