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

  # -- helpers internes --

  # Écrit un contenu "texte" tel quel (PEM brut), en mode atomique + comparaison
  _write_text() { # _write_text "<content>" "<dest>" <mode>
    local content="$1" dest="$2" mode="$3"
    local tmp; tmp="$(mktemp)"
    # On garantit une fin de ligne
    printf '%s\n' "$content" > "$tmp"
    if [[ ! -f "$dest" ]] || ! cmp -s "$tmp" "$dest"; then
      install -D -m "$mode" "$tmp" "$dest"
    fi
    rm -f "$tmp"
  }

  # Écrit depuis un fichier source si différent
  _write_from_file() { # _write_from_file "<src_file>" "<dest>" <mode>
    local src="$1" dest="$2" mode="$3"
    if [[ ! -f "$dest" ]] || ! cmp -s "$src" "$dest"; then
      install -D -m "$mode" "$src" "$dest"
    fi
  }

  # Décodage base64 portable (on retire les blancs/retours avant decode)
  _write_from_b64() { # _write_from_b64 "<b64_data>" "<dest>" <mode>
    local b64="$1" dest="$2" mode="$3"
    local tmp; tmp="$(mktemp)"
    if ! printf '%s' "$b64" | tr -d '\n\r\t ' | base64 -d > "$tmp" 2>/dev/null; then
      rm -f "$tmp"
      log::error "Décodage base64 échoué pour $dest"
      return 1
    fi
    if [[ ! -f "$dest" ]] || ! cmp -s "$tmp" "$dest"; then
      install -D -m "$mode" "$tmp" "$dest"
    fi
    rm -f "$tmp"
  }

  # Décide automatiquement comment écrire: chemin / PEM / base64
  _write_auto() { # _write_auto "<value>" "<dest>" <mode>
    local val="$1" dest="$2" mode="$3"

    if [[ -z "$val" ]]; then
      log::error "Valeur vide pour $dest"
      return 1
    fi

    if [[ -f "$val" ]]; then
      _write_from_file "$val" "$dest" "$mode" || return 1
      return 0
    fi

    # PEM brut collé (commence souvent par -----BEGIN …)
    if [[ "$val" == *"-----BEGIN"* ]]; then
      _write_text "$val" "$dest" "$mode" || return 1
      return 0
    fi

    # Sinon: on tente base64
    _write_from_b64 "$val" "$dest" "$mode" || return 1
  }

  # -- contrôles d'entrée minimaux --
  [[ -n "${CERTKEY:-}"  ]] || { log::error "CERTKEY manquant dans $file_env";  return 1; }
  [[ -n "${CERTPEM:-}"  ]] || { log::error "CERTPEM manquant dans $file_env";  return 1; }
  # BUNDLEPEM est optionnel

  # -- écritures --
  _write_auto  "${CERTKEY}"  "${dir}/certificate.key"  600 || return 1
  _write_auto  "${CERTPEM}"  "${dir}/certificate.pem"  644 || return 1

  if [[ -n "${BUNDLEPEM:-}" ]]; then
    _write_auto "${BUNDLEPEM}" "${dir}/bundle.pem" 644 || return 1
  else
    # fallback si le bundle n'est pas fourni
    [[ -f "${dir}/bundle.pem" ]] || install -D -m 644 "${dir}/certificate.pem" "${dir}/bundle.pem"
  fi

  log::info "Certificats en place dans ${dir}"
}

