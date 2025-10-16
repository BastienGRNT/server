#!/usr/bin/env bash
[[ "${__REPO_SH__:-0}" -eq 1 ]] && return; __REPO_SH__=1
import "log.sh"; import "util.sh"; import "env.sh"

# repo::clone_or_update <ROOT_DIR> [REPO_URL_IN] [BRANCH_IN]
repo::clone_or_update(){
  local ROOT="$1" REPO_URL_IN="${2:-}" BRANCH_IN="${3:-}"
  local env_file="$ROOT/env.server"

  # Charger et/ou compléter depuis arguments
  env::load "$env_file"
  local url="${REPO_URL_IN:-$REPO_URL}"
  local branch="${BRANCH_IN:-$BRANCH}"
  local dir="${APP_DIR:-/opt/monapp}"

  if [[ -z "$url" ]]; then
    log::warn "REPO_URL vide. Exemple: https://github.com/org/projet.git"
    read -r -p "Entrez REPO_URL: " url
  fi
  if [[ -z "$branch" ]]; then
    read -r -p "Entrez BRANCH (default: $BRANCH): " branch
    branch="${branch:-$BRANCH}"
  fi

  log::info "Repo: $url"
  log::info "Branch: $branch"
  log::info "Dossier: $dir"

  util::ensure_dir "$(dirname "$dir")" 755

  if [[ -d "$dir/.git" ]]; then
    log::step "Mise à jour du repo existant"
    ( set -x; git -C "$dir" fetch --all --prune; git -C "$dir" checkout "$branch"; git -C "$dir" pull --ff-only ) || {
      log::err "git update échoué (vérifie identifiants/accès)"
      exit 1
    }
  else
    log::step "Clonage du repo (Git peut demander identifiant/token)"
    # On laisse GIT afficher la progression et demander les creds si nécessaire
    ( set -x; git clone --progress --branch "$branch" "$url" "$dir" ) || {
      log::err "git clone échoué (url/branche/identifiants ?)"
      exit 1
    }
  fi

  # Mise à jour traçabilité dans env.server (sans enregistrer le token !)
  # On réécrit/force REPO_URL/BRANCH/APP_DIR
  awk -v url="$url" -v branch="$branch" -v appdir="$dir" '
    BEGIN{r1=0;r2=0;r3=0}
    /^REPO_URL=/ {print "REPO_URL="url; r1=1; next}
    /^BRANCH=/   {print "BRANCH="branch; r2=1; next}
    /^APP_DIR=/  {print "APP_DIR="appdir; r3=1; next}
    {print}
    END{
      if(!r1) print "REPO_URL="url
      if(!r2) print "BRANCH="branch
      if(!r3) print "APP_DIR="appdir
    }
  ' "$env_file" > "$env_file.tmp" && mv -f "$env_file.tmp" "$env_file"
  log::ok "env.server mis à jour (REPO_URL/BRANCH/APP_DIR)"

  # Recharger dans l'environnement courant
  env::load "$env_file"
}
