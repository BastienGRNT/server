#!/usr/bin/env bash
[[ "${__PKG_SH__:-0}" -eq 1 ]] && return; __PKG_SH__=1
import "log.sh"; import "util.sh"

pkg::pm(){
  if command -v apt >/dev/null 2>&1; then echo "apt"; return; fi
  if command -v dnf >/dev/null 2>&1; then echo "dnf"; return; fi
  if command -v yum >/dev/null 2>&1; then echo "yum"; return; fi
  if command -v apk >/dev/null 2>&1; then echo "apk"; return; fi
  log::err "Package manager non supporté"; exit 1
}

pkg::install(){
  local pm; pm="$(pkg::pm)"
  case "$pm" in
    apt) apt update -y && apt install -y "$@";;
    dnf) dnf install -y "$@";;
    yum) yum install -y -q "$@";;
    apk) apk add --no-cache "$@";;
  esac
}

pkg::install_base(){ log::info "Install base"; pkg::install ca-certificates curl git || true; }
pkg::install_nginx(){
  if command -v nginx >/dev/null 2>&1; then log::ok "Nginx déjà installé ($(nginx -v 2>&1))"
  else
    log::info "Installation Nginx"; pkg::install nginx
    util::is_systemd && { systemctl enable nginx || true; systemctl start nginx || true; }
  fi
}
pkg::install_node_lts(){
  if command -v node >/dev/null 2>&1; then log::ok "Node déjà installé ($(node -v))"; return; fi
  local pm; pm="$(pkg::pm)"
  log::info "Installation Node LTS"
  case "$pm" in
    apt) curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - >/dev/null 2>&1; pkg::install nodejs ;;
    dnf|yum) curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash - >/dev/null 2>&1; pkg::install nodejs ;;
    apk) pkg::install nodejs npm ;;
  esac
  command -v node >/dev/null 2>&1 || { log::err "Échec Node"; exit 1; }
  log::ok "Node $(node -v)"
}
