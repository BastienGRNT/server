#!/usr/bin/env bash
[[ "${__ENV_SH__:-0}" -eq 1 ]] && return; __ENV_SH__=1
import "log.sh"; import "util.sh"

# Fichier .env du projet
env::ensure_file(){
  local path="$1" mode="${2:-check-only}"
  if [[ -f "$path" ]]; then
    log::ok "$path existe déjà"
    return
  fi
  log::info "Création de $path (modèle minimal)"
  util::heredoc "$path" 640 <<'ENV'
# === Variables projet (traceable) ===
# Tout ce qui configure le serveur DOIT être ici pour traçabilité.
# ⚠️ N'insère pas de secrets d'auth Git (token) en clair.
NOM=myapp
TYPE=monolith                 # monolith | static+api | frontserver+api
URL=example.com

# === Repo Git (Git demandera identifiant/token à l'exécution) ===
REPO_URL=
BRANCH=main
APP_DIR=/opt/monapp

# === Ports / Dossiers appli ===
PORT_FRONT=3000
PORT_API=4000
WORKDIR_FRONT=/opt/monapp/src
WORKDIR_API=/opt/monapp/api

# === Commandes de lancement (systemd) ===
FRONT_CMD=
API_CMD=

# === Utilisateur des services ===
USER_SERVICE=www-data

# === Certificats (base64) ===
certkey=
certpem=
bundlepem=
ENV
  [[ "$mode" == "write-missing" ]] || log::ok "Édite $path puis relance."
}

env::load(){
  local path="$1"
  [[ -f "$path" ]] || { log::err "$path introuvable"; exit 1; }
  set -a; source "$path"; set +a

  : "${NOM:?NOM manquant}"
  : "${TYPE:=}"   # peut être défini plus tard par la commande
  : "${URL:?URL manquant}"

  : "${REPO_URL:=}"
  : "${BRANCH:=main}"
  : "${APP_DIR:=/opt/monapp}"

  : "${PORT_FRONT:=3000}"
  : "${PORT_API:=4000}"
  : "${WORKDIR_FRONT:=/opt/monapp/src}"
  : "${WORKDIR_API:=/opt/monapp/api}"
  : "${FRONT_CMD:=}"
  : "${API_CMD:=}"
  : "${USER_SERVICE:=www-data}"

  : "${certkey:=}"
  : "${certpem:=}"
  : "${bundlepem:=}"
}

# Résumé lisible
env::show_effective(){
  log::banner "Configuration effective"
  util::kv "NOM" "$NOM"
  util::kv "TYPE" "${TYPE:-<non défini>}"
  util::kv "URL" "$URL"
  util::kv "REPO_URL" "${REPO_URL:-<non défini>}"
  util::kv "BRANCH" "$BRANCH"
  util::kv "APP_DIR" "$APP_DIR"
  util::kv "PORT_FRONT" "$PORT_FRONT"
  util::kv "PORT_API" "$PORT_API"
  util::kv "WORKDIR_FRONT" "$WORKDIR_FRONT"
  util::kv "WORKDIR_API" "$WORKDIR_API"
  util::kv "USER_SERVICE" "$USER_SERVICE"
  util::kv "FRONT_CMD" "${FRONT_CMD:-<vide>}"
  util::kv "API_CMD" "${API_CMD:-<vide>}"
  util::kv "certkey" "$( [[ -n "$certkey" ]] && echo 'present' || echo 'absent' )"
  util::kv "certpem" "$( [[ -n "$certpem" ]] && echo 'present' || echo 'absent' )"
  util::kv "bundlepem" "$( [[ -n "$bundlepem" ]] && echo 'present' || echo 'absent' )"
}

# Snapshot (audit) + EnvironmentFile pour systemd
env::snapshot(){
  local root="$1" snapshot_type="${2:-}"
  local tstamp; tstamp="$(date +%Y%m%d-%H%M%S)"
  local audit_dir="$root/.env.audit"
  util::ensure_dir "$audit_dir" 750
  local snap_file="$audit_dir/${tstamp}.env"

  util::heredoc "$snap_file" 640 <<EOF
# Snapshot généré le $tstamp
NOM=$NOM
TYPE=${snapshot_type:-${TYPE:-}}
URL=$URL

REPO_URL=$REPO_URL
BRANCH=$BRANCH
APP_DIR=$APP_DIR

PORT_FRONT=$PORT_FRONT
PORT_API=$PORT_API

WORKDIR_FRONT=$WORKDIR_FRONT
WORKDIR_API=$WORKDIR_API
USER_SERVICE=$USER_SERVICE
FRONT_CMD=$FRONT_CMD
API_CMD=$API_CMD

CERT_KEY_PRESENT=$( [[ -n "$certkey" ]] && echo 1 || echo 0 )
CERT_PEM_PRESENT=$( [[ -n "$certpem" ]] && echo 1 || echo 0 )
BUNDLE_PEM_PRESENT=$( [[ -n "$bundlepem" ]] && echo 1 || echo 0 )
EOF
  log::info "Snapshot .env → $snap_file"

  # EnvironmentFile pour systemd
  local ENV_DIR="/etc/opt/${NOM}"
  util::ensure_dir "$ENV_DIR" 750
  util::heredoc "$ENV_DIR/env" 640 <<EOF
NOM=$NOM
URL=$URL
PORT_FRONT=$PORT_FRONT
PORT_API=$PORT_API
WORKDIR_FRONT=$WORKDIR_FRONT
WORKDIR_API=$WORKDIR_API
EOF
}
