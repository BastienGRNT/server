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
  local file="${1:-$ENV_FILE_DEFAULT}"
  env::init_file "$file"
  [[ -f "$file" ]] && env::load "$file" || true

  while true; do
    local CERT_DIR_ CERTKEY_ CERTPEM_ BUNDLEPEM_
    # CERT_DIR simple
    env::_prompt_value CERT_DIR_  "CERT_DIR" "${CERT_DIR:-/opt/certificates}"
    # Les trois suivants acceptent: paste | /chemin | base64
    env::input_cert_value CERTKEY_   "CERTKEY"   "${CERTKEY:-}"   0
    env::input_cert_value CERTPEM_   "CERTPEM"   "${CERTPEM:-}"   0
    env::input_cert_value BUNDLEPEM_ "BUNDLEPEM" "${BUNDLEPEM:-}" 1  # optionnel

    # Récap (on tronque l'affichage pour éviter de spammer l'écran)
    local ckey_preview ccert_preview cbundle_preview
    ckey_preview="$( [[ -z "$CERTKEY_" ]] && echo "<vide>" || ( [[ -f "$CERTKEY_" ]] && echo "file:$CERTKEY_" || echo "base64:$(printf '%s' "$CERTKEY_" | cut -c1-12)…" ) )"
    ccert_preview="$( [[ -z "$CERTPEM_" ]] && echo "<vide>" || ( [[ -f "$CERTPEM_" ]] && echo "file:$CERTPEM_" || echo "base64:$(printf '%s' "$CERTPEM_" | cut -c1-12)…" ) )"
    cbundle_preview="$( [[ -z "$BUNDLEPEM_" ]] && echo "<vide>" || ( [[ -f "$BUNDLEPEM_" ]] && echo "file:$BUNDLEPEM_" || echo "base64:$(printf '%s' "$BUNDLEPEM_" | cut -c1-12)…" ) )"

    env::_recap "Récapitulatif - Certificats" \
      "CERT_DIR=${CERT_DIR_}" \
      "CERTKEY=${ckey_preview}" \
      "CERTPEM=${ccert_preview}" \
      "BUNDLEPEM=${cbundle_preview}"

    if env::_confirm_changes "Confirmer ces valeurs"; then
      env::_apply_kv "$file" "CERT_DIR"  "$CERT_DIR_"
      env::_apply_kv "$file" "CERTKEY"   "$CERTKEY_"
      env::_apply_kv "$file" "CERTPEM"   "$CERTPEM_"
      env::_apply_kv "$file" "BUNDLEPEM" "$BUNDLEPEM_"
      log::info "Certificats enregistrés dans $file"
      return 0
    else
      case $? in
        1) echo "Recommencer...";;
        2) echo "Annulé."; return 2;;
      esac
    fi
  done
}





# --- Helpers certificat ---

# Encode en base64 sur une seule ligne (portable)
env::b64_oneline() {
  base64 | tr -d '\n\r\t '
}

# Teste si une chaîne *semble* décodable en base64
env::looks_base64() {
  local s="$1"
  # On retire les blancs, puis on tente un decode en /dev/null
  printf '%s' "$s" | tr -d '\n\r\t ' | base64 -d >/dev/null 2>&1
}

# Capture un PEM multi-ligne, encode en base64 (1 ligne), demande confirmation
# Retourne la chaine base64 dans la variable passée en 1er argument (nameref)
env::ask_pem_b64() {
  local __outvar="$1" __desc="$2" __optional="${3:-0}"
  local tmp content_b64 bytes_digest
  while true; do
    echo "$__desc"
    echo "(Colle le contenu complet PEM, puis tape 'EOF' seul sur une ligne pour terminer)"
    tmp="$(mktemp)"
    # Lire jusqu'à EOF
    while IFS= read -r line; do
      [[ "$line" == "EOF" ]] && break
      printf '%s\n' "$line" >> "$tmp"
    done
    if [[ ! -s "$tmp" && "$__optional" == "1" ]]; then
      echo "→ Contenu vide accepté."
      content_b64=""
    else
      content_b64="$(env::b64_oneline < "$tmp")"
      bytes_digest=$(wc -c < "$tmp" | tr -d ' ')
      echo "Taille: ${bytes_digest} octets"
      echo "Aperçu: $(head -n1 "$tmp") … $(tail -n1 "$tmp")"
    fi
    rm -f "$tmp"

    if env::_confirm_changes "Confirmer ce contenu"; then
      printf -v "$__outvar" '%s' "$content_b64"
      break
    else
      echo "Ok, on recommence…"
    fi
  done
}

# Lit une valeur pour un cert donné selon 3 modes:
# - 'paste'  : coller un PEM multi-ligne → renvoie base64
# - '/path'  : chemin de fichier existant → renvoie le chemin
# - sinon    : traite la saisie comme base64 (valide avant)
# Params:
#   $1 = nom de variable de sortie
#   $2 = label (ex: "CERTKEY")
#   $3 = valeur par défaut (facultatif)
#   $4 = optional? 1/0 (ex: BUNDLEPEM est optionnel)
env::input_cert_value() {
  local __outvar="$1" __label="$2" __default="${3:-}" __optional="${4:-0}"
  local in
  local hint="(saisis 'paste' pour coller un PEM, ou un /chemin de fichier, ou du base64)"
  if [[ -n "$__default" ]]; then
    # On n'affiche pas la valeur par défaut (sécurité), juste qu'il y en a une
    read -r -p "${__label} ${hint} [défaut présent, Entrée pour conserver]: " in
    in="${in:-__KEEP_DEFAULT__}"
  else
    read -r -p "${__label} ${hint}: " in
  fi

  # Gestion vide/defaut lorsque optionnel
  if [[ -z "$in" && "$__optional" == "1" && -z "$__default" ]]; then
    printf -v "$__outvar" '%s' ""
    return 0
  fi

  # Conserver la valeur précédente
  if [[ "$in" == "__KEEP_DEFAULT__" ]]; then
    printf -v "$__outvar" '%s' "$__default"
    return 0
  fi

  # Mode paste
  if [[ "$in" == "paste" ]]; then
    local b64=""; env::ask_pem_b64 b64 "$__label : coller le PEM puis EOF" "$__optional"
    printf -v "$__outvar" '%s' "$b64"
    return 0
  fi

  # Chemin de fichier ?
  if [[ "$in" == /* && -f "$in" ]]; then
    printf -v "$__outvar" '%s' "$in"
    return 0
  fi

  # Sinon: base64
  if env::looks_base64 "$in"; then
    # On nettoie les blancs
    in="$(printf '%s' "$in" | tr -d '\n\r\t ')"
    printf -v "$__outvar" '%s' "$in"
    return 0
  fi

  echo "Entrée invalide pour $__label. Recommencer."
  env::input_cert_value "$__outvar" "$__label" "$__default" "$__optional"
}