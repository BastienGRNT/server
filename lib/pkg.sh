#!/usr/bin/env bash
# pkg.sh — installateurs

[[ "${__PKG_SH__:-0}" -eq 1 ]] && return; __PKG_SH__=1
import "log.sh"; import "run.sh"; import "util.sh"

pkg::pm(){
  if command -v apt >/dev/null 2>&1; then echo apt; return; fi
  if command -v dnf >/dev/null 2>&1; then echo dnf; return; fi
  if command -v yum >/dev/null 2>&1; then echo yum; return; fi
  if command -v apk >/dev/null 2>&1; then echo apk; return; fi
  log::error "Package manager non supporté"; return 1
}

pkg::install(){
  local pm; pm="$(pkg::pm)" || return 1
  case "$pm" in
    apt) run::exec_quiet "apt update -y && apt install -y $*";;
    dnf) run::exec_quiet "dnf install -y $*";;
    yum) run::exec_quiet "yum install -y -q $*";;
    apk) run::exec_quiet "apk add --no-cache $*";;
  esac
}

pkg::install_node_lts(){
  if command -v node >/dev/null 2>&1; then log::ok "Node déjà installé ($(node -v))"; return; fi
  local pm; pm="$(pkg::pm)"
  log::info "Installation Node LTS"
  case "$pm" in
    apt)      run::exec_quiet "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -" ; pkg::install nodejs ;;
    dnf|yum)  run::exec_quiet "curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -" ; pkg::install nodejs ;;
    apk)      pkg::install nodejs npm ;;
  esac
  command -v node >/dev/null 2>&1 || { log::err "Échec Node"; exit 1; }
  log::ok "Node $(node -v)"
}

pkg::install_nginx(){
  if command -v nginx >/dev/null 2>&1; then log::ok "Nginx déjà installé ($(nginx -v 2>&1))"; return; fi
  local pm; pm="$(pkg::pm)"
  log::info "Installation Nginx"
  case "$pm" in
    apt)      run::exec_quiet "apt update -y && apt install -y nginx" ;;
    dnf)      run::exec_quiet "dnf install -y nginx" ;;
    yum)      run::exec_quiet "yum install -y -q nginx" ;;
    apk)      run::exec_quiet "apk add --no-cache nginx" ;;
  esac
  command -v nginx >/dev/null 2>&1 || { log::err "Échec Nginx"; exit 1; }
  command -v systemctl >/dev/null 2>&1 && run::exec_quiet "systemctl enable --now nginx || true"
  log::ok "Nginx prêt ($(nginx -v 2>&1))"
}

pkg::install_git(){
  if command -v git >/dev/null 2>&1; then log::ok "Git déjà installé ($(git --version))"; return; fi
  local pm; pm="$(pkg::pm)"
  log::info "Installation Git"
  case "$pm" in
    apt)      run::exec_quiet "apt update -y && apt install -y git" ;;
    dnf)      run::exec_quiet "dnf install -y git" ;;
    yum)      run::exec_quiet "yum install -y -q git" ;;
    apk)      run::exec_quiet "apk add --no-cache git" ;;
  esac
  command -v git >/dev/null 2>&1 || { log::err "Échec Git"; exit 1; }
  log::ok "Git prêt ($(git --version))"
}
