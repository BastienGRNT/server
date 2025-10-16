server {
  listen 80;
  listen [::]:80;
  server_name ${URL} www.${URL};
  return 301 https://$host$request_uri;
}
server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name ${URL} www.${URL};

  ssl_certificate         ${CERT_DIR}/certificate.pem;
  ssl_certificate_key     ${CERT_DIR}/certificate.key;
  ssl_trusted_certificate ${CERT_DIR}/bundle.pem;

  location / {
    proxy_pass http://127.0.0.1:${PORT_FRONT};
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_http_version 1.1;
    proxy_set_header Upgrade           $http_upgrade;
    proxy_set_header Connection        "upgrade";
  }
  location /api/ {
    proxy_pass http://127.0.0.1:${PORT_BACK};
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_http_version 1.1;
    proxy_set_header Upgrade           $http_upgrade;
    proxy_set_header Connection        "upgrade";
  }
}
