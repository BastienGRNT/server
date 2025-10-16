#!/usr/bin/env bash
# env.sh — gestion env.server avec confirmation y/n/u

[[ "${__ENV_SH__:-0}" -eq 1 ]] && return; __ENV_SH__=1
import "log.sh"; import "util.sh"

ENV_FILE_DEFAULT="env.server"

env::load() {
  local file="${1:-$ENV_FILE_DEFAULT}"
  [[ -f "$file" ]] || { log::error "$file introuvable"; return 1; }
  set -a; source "$file"; set +a
}

env::init_file() {
  local file="${1:-$ENV_FILE_DEFAULT}"
  if [[ -f "$file" ]]; then log::info "$file existe déjà"; return 0; fi
  util::heredoc_atomic "$file" 640 <<'ENV'
# === Base ===
APP_NAME=
TYPE=monolith                # monolith | static+api | frontserver+api
URL=
APP_DIR=/opt/APP

# === Git ===
REPO_URL=
BRANCH=main

# === Nginx ===
PORT_FRONT=5000
PORT_BACK=3000
BUILD_DIR=
CONF_DIR=/etc/nginx/conf.d
CONF_TYPE=                     # monolith | static+api | frontserver+api
CONF_TPL_DIR=

# === Certificats ===
CERT_DIR=/opt/certificates
CERTKEY=
CERTPEM=
BUNDLEPEM=
ENV
  log::info "Créé: $file"
}

env::_confirm_changes() {
  local title="${1:-Confirmer}"
  while true; do
    printf "%s ? [y=valider / n=recommencer / u=annuler]: " "$title"
    read -r ans
    case "$ans" in
      y|Y) return 0 ;; n|N) return 1 ;; u|U) return 2 ;; *) echo "Réponse invalide. Saisir y, n ou u." ;;
    esac
  done
}

env::_prompt_value() {
  local __varname="$1"; shift
  local __label="$1"; shift
  local __default="${1:-}"
  local __tmp
  if [[ -n "$__default" ]]; then
    read -r -p "${__label} [${__default}]: " __tmp
    __tmp="${__tmp:-$__default}"
  else
    read -r -p "${__label}: " __tmp
  fi
  printf -v "$__varname" "%s" "$__tmp"
}

env::_apply_kv(){ util::env_set "$1" "$2" "$3"; }

env::_recap() {
  local title="$1"; shift
  echo "----------------------------------------"
  echo "$title"
  echo "----------------------------------------"
  local kv
  for kv in "$@"; do printf "  %-15s : %s\n" "${kv%%=*}" "${kv#*=}"; done
  echo "----------------------------------------"
}

env::init_base() {
  local file="${1:-$ENV_FILE_DEFAULT}"; env::init_file "$file"; [[ -f "$file" ]] && env::load "$file" || true
  while true; do
    local APP_NAME_ TYPE_ URL_ APP_DIR_
    env::_prompt_value APP_NAME_ "APP_NAME" "${APP_NAME:-}"
    env::_prompt_value TYPE_ "TYPE (monolith|static+api|frontserver+api)" "${TYPE:-monolith}"
    env::_prompt_value URL_ "URL (ex: example.com)" "${URL:-}"
    env::_prompt_value APP_DIR_ "APP_DIR" "${APP_DIR:-/opt/APP}"
    env::_recap "Récapitulatif - Base" "APP_NAME=${APP_NAME_}" "TYPE=${TYPE_}" "URL=${URL_}" "APP_DIR=${APP_DIR_}"
    if env::_confirm_changes "Confirmer ces valeurs"; then
      env::_apply_kv "$file" "APP_NAME" "$APP_NAME_"
      env::_apply_kv "$file" "TYPE"     "$TYPE_"
      env::_apply_kv "$file" "URL"      "$URL_"
      env::_apply_kv "$file" "APP_DIR"  "$APP_DIR_"
      log::info "Base enregistrée dans $file"; return 0
    else case $? in 1) echo "Recommencer...";; 2) echo "Annulé."; return 2;; esac fi
  done
}

env::init_git() {
  local file="${1:-$ENV_FILE_DEFAULT}"; env::init_file "$file"; [[ -f "$file" ]] && env::load "$file" || true
  while true; do
    local REPO_URL_ BRANCH_
    env::_prompt_value REPO_URL_ "REPO_URL" "${REPO_URL:-}"
    env::_prompt_value BRANCH_ "BRANCH" "${BRANCH:-main}"
    env::_recap "Récapitulatif - Git" "REPO_URL=${REPO_URL_}" "BRANCH=${BRANCH_}"
    if env::_confirm_changes "Confirmer ces valeurs"; then
      env::_apply_kv "$file" "REPO_URL" "$REPO_URL_"
      env::_apply_kv "$file" "BRANCH"   "$BRANCH_"
      log::info "Git enregistré dans $file"; return 0
    else case $? in 1) echo "Recommencer...";; 2) echo "Annulé."; return 2;; esac fi
  done
}

env::init_nginx() {
  local file="${1:-$ENV_FILE_DEFAULT}"; env::init_file "$file"; [[ -f "$file" ]] && env::load "$file" || true
  while true; do
    local PORT_FRONT_ PORT_BACK_ BUILD_DIR_ CONF_DIR_ CONF_TYPE_ CONF_TPL_DIR_
    env::_prompt_value PORT_FRONT_ "PORT_FRONT" "${PORT_FRONT:-5000}"
    env::_prompt_value PORT_BACK_  "PORT_BACK"  "${PORT_BACK:-3000}"
    env::_prompt_value BUILD_DIR_  "BUILD_DIR (si static)" "${BUILD_DIR:-}"
    env::_prompt_value CONF_DIR_   "CONF_DIR" "${CONF_DIR:-/etc/nginx/conf.d}"
    env::_prompt_value CONF_TYPE_  "CONF_TYPE (monolith|static+api|frontserver+api)" "${CONF_TYPE:-${TYPE:-}}"
    env::_prompt_value CONF_TPL_DIR_ "CONF_TPL_DIR (chemin des templates)" "${CONF_TPL_DIR:-}"
    env::_recap "Récapitulatif - Nginx" \
      "PORT_FRONT=${PORT_FRONT_}" "PORT_BACK=${PORT_BACK_}" "BUILD_DIR=${BUILD_DIR_}" \
      "CONF_DIR=${CONF_DIR_}" "CONF_TYPE=${CONF_TYPE_}" "CONF_TPL_DIR=${CONF_TPL_DIR_}"
    if env::_confirm_changes "Confirmer ces valeurs"; then
      env::_apply_kv "$file" "PORT_FRONT"   "$PORT_FRONT_"
      env::_apply_kv "$file" "PORT_BACK"    "$PORT_BACK_"
      env::_apply_kv "$file" "BUILD_DIR"    "$BUILD_DIR_"
      env::_apply_kv "$file" "CONF_DIR"     "$CONF_DIR_"
      env::_apply_kv "$file" "CONF_TYPE"    "$CONF_TYPE_"
      env::_apply_kv "$file" "CONF_TPL_DIR" "$CONF_TPL_DIR_"
      log::info "Nginx enregistré dans $file"; return 0
    else case $? in 1) echo "Recommencer...";; 2) echo "Annulé."; return 2;; esac fi
  done
}

env::init_certificate() {
  local file="${1:-$ENV_FILE_DEFAULT}"; env::init_file "$file"; [[ -f "$file" ]] && env::load "$file" || true
  while true; do
    local CERT_DIR_ CERTKEY_ CERTPEM_ BUNDLEPEM_
    env::_prompt_value CERT_DIR_  "CERT_DIR" "${CERT_DIR:-/opt/certificates}"
    env::_prompt_value CERTKEY_   "CERTKEY (base64 ou chemin)" "${CERTKEY:-}"
    env::_prompt_value CERTPEM_   "CERTPEM (base64 ou chemin)" "${CERTPEM:-}"
    env::_prompt_value BUNDLEPEM_ "BUNDLEPEM (base64 ou chemin, optionnel)" "${BUNDLEPEM:-}"
    env::_recap "Récapitulatif - Certificats" \
      "CERT_DIR=${CERT_DIR_}" "CERTKEY=${CERTKEY_}" "CERTPEM=${CERTPEM_}" "BUNDLEPEM=${BUNDLEPEM_}"
    if env::_confirm_changes "Confirmer ces valeurs"; then
      env::_apply_kv "$file" "CERT_DIR"  "$CERT_DIR_"
      env::_apply_kv "$file" "CERTKEY"   "$CERTKEY_"
      env::_apply_kv "$file" "CERTPEM"   "$CERTPEM_"
      env::_apply_kv "$file" "BUNDLEPEM" "$BUNDLEPEM_"
      log::info "Certificats enregistrés dans $file"; return 0
    else case $? in 1) echo "Recommencer...";; 2) echo "Annulé."; return 2;; esac fi
  done
}

env::edit_base()        { env::init_base "$@"; }
env::edit_git()         { env::init_git "$@"; }
env::edit_nginx()       { env::init_nginx "$@"; }
env::edit_certificate() { env::init_certificate "$@"; }

env::snapshot() {
  local file="${1:-$ENV_FILE_DEFAULT}" root="${2:-.}"
  local t; t="$(date +%Y%m%d-%H%M%S)"
  local dir="$root/.env.audit"; util::ensure_dir "$dir" 750
  cp -f "$file" "$dir/${t}.env"
  log::info "Snapshot: $dir/${t}.env"
}
