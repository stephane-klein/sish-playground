#!/usr/bin/env bash
set -e

PROJECT_FOLDER="/srv/powerdns/"

mkdir -p ${PROJECT_FOLDER}

cat <<'EOF' > "${PROJECT_FOLDER}docker-compose.yaml"
services:
  powerdns:
    image: powerdns/pdns-auth-49:4.9.3
    restart: unless-stopped
    environment:
      PDNS_AUTH_API_KEY: password
    healthcheck:
      test: ["CMD", "pdns_control", "rping"]
      interval: 60s
      start_period: 10s
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "8081:8081"
    volumes:
      - powerdns_sqlite:/var/lib/powerdns/

  powerdns_admin:
    image: powerdnsadmin/pda-legacy:v0.4.2
    environment:
      POWERDNS_ADMIN_USERNAME: admin
      POWERDNS_ADMIN_PASSWORD: password
      POWERDNS_ADMIN_EMAIL: admin@example.com
      SQLALCHEMY_DATABASE_URI: "sqlite:////data/powerdns-admin.db"
      PDNS_API_URL: "http://powerdns:8081"
      PDNS_API_KEY: "password"
      PDNS_VERSION: "4.9.3"
      SIGNUP_ENABLED: "false"
    volumes:
      - powerdns_admin_sqlite:/data/
    ports:
      - "9191:80"
    depends_on:
      powerdns:
        condition: service_healthy

volumes:
  powerdns_sqlite:
     name: powerdns_sqlite
  powerdns_admin_sqlite:
     name: powerdns_admin_sqlite
EOF

cat <<'EOF' > "${PROJECT_FOLDER}configure_powerdns_admin.py"
#!/usr/bin/env python3
import os
from powerdnsadmin.models.user import User
from powerdnsadmin import create_app

app = create_app()

with app.app_context():
    user = User(
        username=os.getenv("POWERDNS_ADMIN_USERNAME", "admin"),
        plain_text_password=os.getenv("POWERDNS_ADMIN_PASSWORD", "password"),
        email=os.getenv("POWERDNS_ADMIN_EMAIL", "admin@example.com"),
        confirmed=True
    )
    result = user.create_local_user()
    print(result["msg"])
EOF
chmod u+x ${PROJECT_FOLDER}configure_powerdns_admin.py

systemctl stop systemd-resolved
systemctl disable systemd-resolved
rm /etc/resolv.conf
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

ufw allow 53 # dns
ufw allow 8081 # powerdns
ufw allow 9191 # powerdns_admin

cd ${PROJECT_FOLDER}
docker compose pull

docker compose up -d --wait --remove-orphans

CONTAINER_NAME=$(docker compose ps -q powerdns_admin)

docker cp "configure_powerdns_admin.py" "$CONTAINER_NAME:/app/configure_powerdns_admin.py"

docker compose exec powerdns_admin /app/configure_powerdns_admin.py
