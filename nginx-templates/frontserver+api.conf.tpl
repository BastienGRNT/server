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

  add_header Strict-Transport-Security "max-age=15552000; includeSubDomains" always;
  add_header X-Content-Type-Options "nosniff" always;
  add_header X-Frame-Options "SAMEORIGIN" always;
  add_header Referrer-Policy "strict-origin-when-cross-origin" always;
  gzip on; gzip_comp_level 5; gzip_min_length 1024;
  gzip_types text/plain text/css application/javascript application/json application/xml image/svg+xml;
  server_tokens off;

  location / {
    proxy_pass http://127.0.0.1:${PORT_FRONT};
    proxy_http_version 1.1;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade           $http_upgrade;
    proxy_set_header Connection        "upgrade";
    proxy_read_timeout 60s;
  }
  location /api/ {
    proxy_pass http://127.0.0.1:${PORT_API};
    proxy_http_version 1.1;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade           $http_upgrade;
    proxy_set_header Connection        "upgrade";
    proxy_read_timeout 60s;
  }
}
