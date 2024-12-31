#!/usr/bin/env bash
set -e

PROJECT_FOLDER="/srv/dnsrobocert/"

mkdir -p ${PROJECT_FOLDER}

mkdir -p /etc/dnsrobocert
cat <<'EOF' > "/etc/dnsrobocert/config.yml"
draft: false
acme:
  email_account: contact@stephane-klein.info
  staging: false
profiles:
- name: powerdns_profile
  provider: powerdns
  provider_options:
    auth_token: password
    pdns_server: "http://51.15.223.53:8081"
    pdns_server_id: localhost
    pdns_disable_notify: 1
certificates:
- domains:
  - "playground.stephane-klein.info"
  - "*.playground.stephane-klein.info"
  profile: powerdns_profile
EOF

cat <<'EOF' > "${PROJECT_FOLDER}docker-compose.yaml"
services:
  dnsrobocert:
    image: adferrand/dnsrobocert:3.25.0
    environment:
      LOG_LEVEL: INFO
    restart: unless-stopped
    volumes:
      - /etc/dnsrobocert/config.yml:/etc/dnsrobocert/config.yml
      - /etc/letsencrypt:/etc/letsencrypt
EOF

cd ${PROJECT_FOLDER}

docker compose pull
docker compose stop
docker compose up -d --wait --remove-orphans
