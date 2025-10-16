#!/usr/bin/env bash
[[ "${__SYSTEMD_SH__:-0}" -eq 1 ]] && return; __SYSTEMD_SH__=1
import "log.sh"; import "util.sh"

systemd::write_envfile(){
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
  echo "$ENV_DIR/env"
}

systemd::make_unit(){
  local name="$1" workdir="$2" cmd="$3"
  [[ -n "$cmd" ]] || { log::err "Commande vide pour $name"; exit 1; }
  local unit="/etc/systemd/system/${name}.service"
  util::heredoc "$unit" 644 <<UNIT
[Unit]
Description=${NOM} - ${name}
After=network.target

[Service]
Type=simple
User=${USER_SERVICE}
EnvironmentFile=/etc/opt/${NOM}/env
WorkingDirectory=${workdir}
ExecStart=/bin/bash -lc '${cmd}'
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
UNIT
  echo "$unit"
}

systemd::deploy(){
  util::is_systemd || { log::err "systemd non détecté"; exit 1; }
  local TYPE="$1"
  local envfile; envfile="$(systemd::write_envfile)"
  log::info "EnvironmentFile: $envfile"

  case "$TYPE" in
    monolith)
      [[ -n "${FRONT_CMD}" ]] || { log::err "FRONT_CMD requis"; exit 1; }
      systemd::make_unit "${NOM}-front" "${WORKDIR_FRONT}" "${FRONT_CMD}"
      systemctl daemon-reload
      systemctl enable --now "${NOM}-front"
      ;;
    static+api)
      [[ -n "${API_CMD}"   ]] || { log::err "API_CMD requis"; exit 1; }
      systemd::make_unit "${NOM}-api"   "${WORKDIR_API}"   "${API_CMD}"
      systemctl daemon-reload
      systemctl enable --now "${NOM}-api"
      ;;
    frontserver+api)
      [[ -n "${FRONT_CMD}" && -n "${API_CMD}" ]] || { log::err "FRONT_CMD et API_CMD requis"; exit 1; }
      systemd::make_unit "${NOM}-front" "${WORKDIR_FRONT}" "${FRONT_CMD}"
      systemd::make_unit "${NOM}-api"   "${WORKDIR_API}"   "${API_CMD}"
      systemctl daemon-reload
      systemctl enable --now "${NOM}-front" "${NOM}-api"
      ;;
    *)
      log::err "Type inconnu: $TYPE"; exit 1;;
  esac

  log::ok "Services actifs. Logs:"
  echo "  journalctl -u ${NOM}-front -f   # si front"
  echo "  journalctl -u ${NOM}-api -f     # si api"
}
