#!/usr/bin/env bash
# repo.sh — clone/update dans /opt/<APP_NAME>

[[ "${__REPO_SH__:-0}" -eq 1 ]] && return; __REPO_SH__=1
import "log.sh"; import "run.sh"; import "env.sh"; import "util.sh"; import "pkg.sh"

# repo::clone_or_update <ROOT_DIR> [REPO_URL_IN] [BRANCH_IN]
repo::clone_or_update(){
  local ROOT="$1" REPO_URL_IN="${2:-}" BRANCH_IN="${3:-}"
  local env_file="$ROOT/env.server"

  env::load "$env_file"   || return 1
  pkg::install_git        || return 1

  local url="${REPO_URL_IN:-$REPO_URL}"
  local branch="${BRANCH_IN:-$BRANCH}"
  local app="${APP_NAME:?APP_NAME requis dans $env_file}"

  [[ -n "$url" ]] || { log::err "REPO_URL manquant (flag --repo ou dans $env_file)"; return 1; }
  [[ -n "$branch" ]] || branch="main"

  local base="/opt"
  local dir="$base/$app"

  util::kv "URL"     "$url"
  util::kv "Branch"  "$branch"
  util::kv "Cible"   "$dir"

  util::ensure_dir "$base" 755

  export GIT_TERMINAL_PROMPT=1
  unset GIT_ASKPASS SSH_ASKPASS

  if [[ -d "$dir/.git" ]]; then
    run::exec_show "git -C \"$dir\" fetch --all --prune"
    run::exec_show "git -C \"$dir\" checkout \"$branch\""
    run::exec_show "git -C \"$dir\" pull --ff-only"
    log::ok "Repo mis à jour"
  else
    if [[ -d "$dir" && -n "$(ls -A "$dir" 2>/dev/null)" ]]; then
      log::err "Le répertoire $dir existe et n'est pas vide (et pas un repo git)."; return 1
    fi
    run::exec_show "git clone --progress --branch \"$branch\" \"$url\" \"$dir\""
    log::ok "Cloné dans $dir"
  fi

  util::env_set "$env_file" "APP_DIR"  "$dir"
  util::env_set "$env_file" "BRANCH"   "$branch"
  util::env_set "$env_file" "REPO_URL" "$url"
  env::load "$env_file"
}
