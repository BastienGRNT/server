#!/usr/bin/env bash
[[ "${__NGINX_SH__:-0}" -eq 1 ]] && return; __NGINX_SH__=1
import "log.sh"; import "util.sh"

nginx::write_certs(){
  local CERT_DIR="/etc/ssl"
  util::ensure_dir "$CERT_DIR" 700
  [[ -n "${certkey:-}"  ]] || { log::err "certkey manquant (base64)"; exit 1; }
  [[ -n "${certpem:-}"  ]] || { log::err "certpem manquant (base64)"; exit 1; }
  printf '%s' "$certkey" | base64 -d > "${CERT_DIR}/certificate.key"
  printf '%s' "$certpem" | base64 -d > "${CERT_DIR}/certificate.pem"
  if [[ -n "${bundlepem:-}" ]]; then
    printf '%s' "$bundlepem" | base64 -d > "${CERT_DIR}/bundle.pem"
  else
    cp -f "${CERT_DIR}/certificate.pem" "${CERT_DIR}/bundle.pem"
  fi
  chown root:root "${CERT_DIR}/certificate.key" "${CERT_DIR}/certificate.pem" "${CERT_DIR}/bundle.pem"
  chmod 600 "${CERT_DIR}/certificate.key"
  chmod 644 "${CERT_DIR}/certificate.pem" "${CERT_DIR}/bundle.pem"
  echo "$CERT_DIR"
}

nginx::deploy(){
  local TYPE="$1" TPL_DIR="$2"
  [[ -n "$TYPE" && -d "$TPL_DIR" ]] || { log::err "nginx::deploy usage"; exit 1; }

  local CERT_DIR="$(nginx::write_certs)"

  local TPL
  case "$TYPE" in
    monolith)        TPL="$TPL_DIR/monolith.conf.tpl" ;;
    static+api)      TPL="$TPL_DIR/static+api.conf.tpl" ;;
    frontserver+api) TPL="$TPL_DIR/frontserver+api.conf.tpl" ;;
    *) log::err "Type inconnu: $TYPE"; exit 1;;
  esac
  [[ -f "$TPL" ]] || { log::err "Template absent: $TPL"; exit 1; }

  local CONF="/etc/nginx/conf.d/${NOM}.conf"
  export URL CERT_DIR PORT_FRONT PORT_API
  local tmp_conf; tmp_conf="$(mktemp)"
  envsubst < "$TPL" > "$tmp_conf"
  mv -f "$tmp_conf" "$CONF"

  log::step "Validation Nginx"
  nginx -t
  (systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true)
  log::ok "Nginx déployé ($TYPE) → $CONF"
}