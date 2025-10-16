#!/usr/bin/env bash
[[ "${__REPO_SH__:-0}" -eq 1 ]] && return; __REPO_SH__=1
import "log.sh"; import "util.sh"; import "env.sh"

# repo::clone_or_update <ROOT_DIR> [REPO_URL_IN] [BRANCH_IN]
repo::clone_or_update(){
  local ROOT="$1" REPO_URL_IN="${2:-}" BRANCH_IN="${3:-}"
  local env_file="$ROOT/env.server"

  # Charger l'env (pour récupérer REPO_URL/BRANCH/APP_DIR s'ils existent déjà)
  env::load "$env_file"

  # SANS AUCUN PROMPT : on prend d'abord les flags, sinon .env, sinon erreur
  local url="${REPO_URL_IN:-$REPO_URL}"
  local branch="${BRANCH_IN:-$BRANCH}"
  local dir="${APP_DIR:-/opt/monapp}"

  [[ -n "$url" ]] || { log::err "REPO_URL manquant (fournis --repo <url> ou mets-le dans env.server)"; exit 1; }
  [[ -n "$branch" ]] || branch="main"

  log::banner "Git repository"
  util::kv "URL"    "$url"
  util::kv "Branch" "$branch"
  util::kv "Dossier" "$dir"

  util::ensure_dir "$(dirname "$dir")" 755

  # Assurer que Git posera les questions d'identifiants dans le TTY
  export GIT_TERMINAL_PROMPT=1
  unset GIT_ASKPASS
  unset SSH_ASKPASS

  if [[ -d "$dir/.git" ]]; then
    log::step "Mise à jour du repo existant"
    # Laisser Git afficher sa progression et demander les creds si nécessaire
    git -C "$dir" fetch --all --prune
    git -C "$dir" checkout "$branch"
    git -C "$dir" pull --ff-only
  else
    log::step "Clonage du repo (Git demandera identifiant/token si nécessaire)"
    git clone --progress --branch "$branch" "$url" "$dir"
  fi

  # Traçabilité: forcer REPO_URL/BRANCH/APP_DIR dans env.server (sans token)
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
  env::load "$env_file"
}
