#!/usr/bin/env bash
set -e

PROJECT_FOLDER="/srv/sish/"

mkdir -p ${PROJECT_FOLDER}

if [ ! -f "${PROJECT_FOLDER}/pubkeys/id_rsa_2016.pub" ]; then
    wget https://sklein.xyz/id_rsa_2016.pub -O "${PROJECT_FOLDER}/pubkeys/id_rsa_2016.pub"
fi

mkdir -p "${PROJECT_FOLDER}/ssl/"

if [ ! -L "${PROJECT_FOLDER}/ssl/playground.stephane-klein.info.crt" ]; then
    ln -s /etc/letsencrypt/live/playground.stephane-klein.info/fullchain.pem "${PROJECT_FOLDER}/ssl/playground.stephane-klein.info.crt"
fi

if [ ! -L "${PROJECT_FOLDER}/ssl/playground.stephane-klein.info.key" ]; then
    ln -s /etc/letsencrypt/live/playground.stephane-klein.info/privkey.pem "${PROJECT_FOLDER}/ssl/playground.stephane-klein.info.key"
fi

cat <<'EOF' > "${PROJECT_FOLDER}docker-compose.yaml"
services:
  sish:
    image: antoniomika/sish:v2.16.0
    restart: unless-stopped
    network_mode: host
    volumes:
      - /etc/letsencrypt/:/etc/letsencrypt/
      - ./pubkeys/:/pubkeys/
      - ./keys/:/keys/
      - ./ssl/:/ssl/
    command: >
      --ssh-address=:2222
      --http-address=:80
      --https-address=:443
      --https=true
      --https-certificate-directory=/ssl
      --authentication-keys-directory=/pubkeys
      --private-keys-directory=/keys
      --bind-random-ports=false
      --bind-random-subdomains=false
      --domain=playground.stephane-klein.info
EOF

ufw allow 2222 # ssh port
ufw allow 80
ufw allow 443

cd ${PROJECT_FOLDER}

docker compose pull
docker compose stop
docker compose up -d --wait --remove-orphans
