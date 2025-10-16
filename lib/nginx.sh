#!/usr/bin/env bash
# nginx.sh — certificats + conf via templates + reload

[[ "${__NGINX_SH__:-0}" -eq 1 ]] && return; __NGINX_SH__=1
import "log.sh"; import "run.sh"; import "util.sh"; import "env.sh"; import "pkg.sh"

nginx::reload() {
  if ! command -v nginx >/dev/null 2>&1; then
    log::info "nginx non trouvé, tentative d'installation"
    pkg::install_nginx || { log::error "Impossible d'installer nginx"; return 1; }
  fi
  run::exec_quiet "nginx -t" || { log::error "nginx -t invalide"; return 1; }
  if command -v systemctl >/dev/null 2>&1; then
    run::exec_quiet "systemctl reload nginx || systemctl restart nginx"
  else
    run::exec_quiet "nginx -s reload || true"
  fi
  log::info "nginx rechargé"
}

nginx::conf() {
  local file_env="${1:-env.server}" tpl_dir_in="${2:-}"
  env::load "$file_env" || return 1
  local app="${APP_NAME:?APP_NAME requis dans $file_env}"
  local host="${URL:?URL requis dans $file_env}"
  local conf_dir="${CONF_DIR:-/etc/nginx/conf.d}"
  local type="${CONF_TYPE:-${TYPE:-}}"
  local pf="${PORT_FRONT:-5000}" pb="${PORT_BACK:-3000}" build="${BUILD_DIR:-/var/www/front}"
  local cert_dir="${CERT_DIR:-/opt/certificates}"
  [[ -n "$type" ]] || { log::error "CONF_TYPE/TYPE manquant"; return 1; }

  local script_root; script_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd -P)"
  local tpl_dir="${tpl_dir_in:-${CONF_TPL_DIR:-$script_root/nginx-templates}}"
  util::ensure_dir "$conf_dir" 755

  local tpl
  case "$type" in
    monolith)        tpl="$tpl_dir/monolith.conf.tpl" ;;
    static+api)      tpl="$tpl_dir/static+api.conf.tpl" ;;
    frontserver+api) tpl="$tpl_dir/frontserver+api.conf.tpl" ;;
    *) log::error "Type inconnu: $type"; return 1 ;;
  esac
  [[ -f "$tpl" ]] || { log::error "Template introuvable: $tpl"; return 1; }

  export URL="$host" CERT_DIR="$cert_dir" PORT_FRONT="$pf" PORT_BACK="$pb" BUILD_DIR="$build"
  local out="$conf_dir/${app}.conf" tmp; tmp="$(mktemp)"
  envsubst < "$tpl" > "$tmp" || { rm -f "$tmp"; log::error "envsubst a échoué"; return 1; }

  if [[ -f "$out" ]] && cmp -s "$tmp" "$out"; then rm -f "$tmp"; log::info "Conf Nginx inchangée: $out"
  else install -D -m 644 "$tmp" "$out"; rm -f "$tmp"; log::info "Conf Nginx écrite: $out"; fi
}

nginx::certificate() {
  local file_env="${1:-env.server}"
  env::load "$file_env" || return 1
  local dir="${CERT_DIR:-/opt/certificates}"
  util::ensure_dir "$dir" 700

  _write_cert() {
    local src="$1" dest="$2" mode="$3"
    if [[ -f "$src" ]]; then
      cmp -s "$src" "$dest" || install -D -m "$mode" "$src" "$dest"
    else
      local tmp; tmp="$(mktemp)"
      if ! printf '%s' "$src" | base64 -d > "$tmp" 2>/dev/null; then rm -f "$tmp"; log::error "Décodage base64 échoué pour $dest"; return 1; fi
      if [[ ! -f "$dest" ]] || ! cmp -s "$tmp" "$dest"; then install -D -m "$mode" "$tmp" "$dest"; fi
      rm -f "$tmp"
    fi
  }

  [[ -n "${CERTKEY:-}" ]] || { log::error "CERTKEY manquant"; return 1; }
  [[ -n "${CERTPEM:-}" ]] || { log::error "CERTPEM manquant"; return 1; }
  _write_cert "$CERTKEY"  "$dir/certificate.key" 600 || return 1
  _write_cert "$CERTPEM"  "$dir/certificate.pem" 644 || return 1
  if [[ -n "${BUNDLEPEM:-}" ]]; then _write_cert "$BUNDLEPEM" "$dir/bundle.pem" 644 || return 1
  else [[ -f "$dir/bundle.pem" ]] || install -D -m 644 "$dir/certificate.pem" "$dir/bundle.pem"; fi
  log::info "Certificats en place dans $dir"
}
