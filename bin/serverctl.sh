#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# Bootstrap & modules
source "$ROOT_DIR/lib/_bootstrap.sh"
import "log.sh"
import "util.sh"
import "pkg.sh"
import "env.sh"
import "repo.sh"
import "nginx.sh"
import "systemd.sh"

# Default log env (overridable via CLI flags or env)
: "${LOG_TAG:=serverctl}"
: "${LOG_LEVEL:=info}"
: "${LOG_TS:=1}"
: "${NO_COLOR:=0}"
: "${LOG_THEME:=emoji}"   # emoji|minimal|plain|json

usage() {
  cat <<USAGE
Usage: serverctl <commande> [options]

Commandes principales:
  all --type <t> [--repo <url>] [--branch <b>]     Provision complet (init -> env -> repo -> nginx -> systemd)
  init                                             Installe paquets de base (nginx, node LTS), prépare dossiers
  env [--write-missing]                            Crée/valide .env (env.server) et charge variables
  repo clone [--repo <url>] [--branch <b>]        Clone ou met à jour le repo (git demandera identifiant/token)
  nginx --type <t>                                 Déploie la conf Nginx depuis templates
  systemd --type <t>                               Crée/active services systemd selon le type
  config show                                      Affiche les variables effectives (masque secrets)
  logs tee <file>                                  Redirige stdout/stderr vers un fichier (tee -a)

Options globales:
  --debug | --quiet | --log-level <lvl>            (debug|info|warn|error|silent)
  --no-color | --theme <emoji|minimal|plain|json>
  --help

Exemples:
  sudo serverctl all --type monolith --repo https://github.com/org/projet.git --branch main
  sudo serverctl repo clone --repo https://github.com/org/projet.git --branch develop
  sudo serverctl nginx --type static+api
USAGE
}

# Parse flags globaux
GLOBAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug) LOG_LEVEL="debug"; shift ;;
    --quiet) LOG_LEVEL="silent"; shift ;;
    --log-level) LOG_LEVEL="${2:-info}"; shift 2 ;;
    --no-color) NO_COLOR=1; shift ;;
    --theme) LOG_THEME="${2:-emoji}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) GLOBAL_ARGS+=("$1"); shift ;;
  esac
done
set -- "${GLOBAL_ARGS[@]}"

log::init "$LOG_LEVEL" "$NO_COLOR" "$LOG_TS" "$LOG_THEME" "$LOG_TAG"

cmd="${1:-}"; shift || true
case "${cmd}" in
  init)
    util::require_root
    log::banner "Initialisation du serveur"
    log::step "Packages de base"
    pkg::install_base
    log::step "Nginx"
    pkg::install_nginx
    log::step "Node.js LTS"
    pkg::install_node_lts
    log::step "Dossier front statique"
    util::ensure_dir "/var/www/front" 755
    log::ok "Init terminé"
    ;;
  env)
    util::require_root
    sub="${1:-}"; [[ -n "$sub" ]] && shift || true
    log::banner "Gestion .env"
    env_path="$ROOT_DIR/env.server"
    if [[ "$sub" == "--write-missing" ]]; then
      env::ensure_file "$env_path" "write-missing"
    else
      env::ensure_file "$env_path"
    fi
    env::load "$env_path"
    env::snapshot "$ROOT_DIR"
    log::ok ".env OK"
    ;;
  repo)
    util::require_root
    action="${1:-}"; shift || true
    case "$action" in
      clone)
        # Flags optionnels
        REPO_URL_IN=""; BRANCH_IN=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --repo) REPO_URL_IN="$2"; shift 2 ;;
            --branch) BRANCH_IN="$2"; shift 2 ;;
            *) break ;;
          esac
        done
        env::ensure_file "$ROOT_DIR/env.server"
        env::load "$ROOT_DIR/env.server"
        repo::clone_or_update "$ROOT_DIR" "$REPO_URL_IN" "$BRANCH_IN"
        env::snapshot "$ROOT_DIR"
        ;;
      *) log::err "repo: action inconnue (use: repo clone)"; usage; exit 1 ;;
    esac
    ;;
  nginx)
    util::require_root
    [[ "${1:-}" == "--type" ]] || { log::err "Utilise: serverctl nginx --type <type>"; exit 1; }
    TYPE="$2"; shift 2
    env::load "$ROOT_DIR/env.server"
    nginx::deploy "$TYPE" "$ROOT_DIR/nginx-templates"
    env::snapshot "$ROOT_DIR" "$TYPE"
    ;;
  systemd)
    util::require_root
    [[ "${1:-}" == "--type" ]] || { log::err "Utilise: serverctl systemd --type <type>"; exit 1; }
    TYPE="$2"; shift 2
    env::load "$ROOT_DIR/env.server"
    systemd::deploy "$TYPE"
    env::snapshot "$ROOT_DIR" "$TYPE"
    ;;
  all)
    util::require_root
    [[ "${1:-}" == "--type" ]] || { log::err "Utilise: serverctl all --type <type> [--repo <url>] [--branch <b>]"; exit 1; }
    TYPE="$2"; shift 2
    REPO_URL_IN=""; BRANCH_IN=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --repo) REPO_URL_IN="$2"; shift 2 ;;
        --branch) BRANCH_IN="$2"; shift 2 ;;
        *) break ;;
      esac
    done
    log::banner "Provision complet (type=$TYPE)"
    log::step "Init serveur"
    pkg::install_base; pkg::install_nginx; pkg::install_node_lts; util::ensure_dir "/var/www/front" 755

    log::step "Environnement (.env)"
    env::ensure_file "$ROOT_DIR/env.server" "write-missing"
    env::load "$ROOT_DIR/env.server"

    log::step "Repo (git)"

    log::step "Nginx ($TYPE)"
    nginx::deploy "$TYPE" "$ROOT_DIR/nginx-templates"

    log::step "systemd ($TYPE)"
    systemd::deploy "$TYPE"

    env::snapshot "$ROOT_DIR" "$TYPE"
    log::ok "🎉 Provision terminé"
    ;;
  config)
    sub="${1:-}"; shift || true
    case "$sub" in
      show)
        env::load "$ROOT_DIR/env.server"
        env::show_effective
        ;;
      *) log::err "config: action inconnue (use: config show)"; usage; exit 1 ;;
    esac
    ;;
  logs)
    [[ "${1:-}" == "tee" ]] || { log::err "logs: use logs tee <file>"; exit 1; }
    file="${2:-}"; [[ -n "$file" ]] || { log::err "logs: file manquant"; exit 1; }
    log::tee "$file"
    ;;
  ""|"-h"|"--help") usage ;;
  *)
    log::err "Commande inconnue: ${cmd}"; usage; exit 1;;
esac
