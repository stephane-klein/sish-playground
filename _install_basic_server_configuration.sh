#!/usr/bin/env bash

set -evuo pipefail

export DEBIAN_FRONTEND=noninteractive
echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections
apt-get update -y
apt-get upgrade -y
apt-get install -yq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    ufw \
    ipset \
    fail2ban \
    jq

# Basic safety element configuration, inspired by article https://kenhv.com/blog/securing-a-linux-server

usermod root --shell /sbin/nologin
passwd --lock root

cat <<'EOF' > /etc/ssh/sshd_config.d/99-custom-security.conf
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
KbdInteractiveAuthentication no
X11Forwarding no
EOF

cat <<'EOF' > /etc/ssh/sshd_config.d/99-custom-display.conf
PrintLastLog no
EOF

cat <<'EOF' > /etc/update-motd.d/00-header
#!/bin/sh
printf "Welcome to %s server\n" "$(hostname --long)"
EOF

rm -f /etc/update-motd.d/10-help-text
rm -f /etc/update-motd.d/50-landscape-sysinfo
rm -f /etc/update-motd.d/90-updates-available
rm -f /etc/update-motd.d/91-contract-ua-esm-status

systemctl restart ssh

ufw allow 22/tcp comment "OpenSSH"
ufw --force enable

# Configure ipsum filter, more information: https://kenhv.com/blog/securing-a-linux-server
# https://github.com/stamparm/ipsum

cat <<'EOF' > /usr/local/bin/ipsum.sh
#!/bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

exec > /dev/kmsg 2>&1

TMP=/tmp/ipsum.txt

until curl --head --silent --fail https://raw.githubusercontent.com/stamparm/ipsum/master/ipsum.txt > /dev/null 2>&1; do
  echo "Waiting for GitHub to be accessible"
  sleep 1
done

while true; do
  until curl --compressed https://raw.githubusercontent.com/stamparm/ipsum/master/ipsum.txt > $TMP 2>/dev/null; do
    echo "Retrying ipsum download"
  done

  if [ $(stat -c%s $TMP) -le 65536 ]; then
    echo "WARNING: Downloaded ipsum firewall database looks wrong, retrying"
  else
    break
  fi

  sleep 1
done

echo "Updating firewall data"

LINES=$(cat $TMP | grep -v '#' | wc -l)
echo "Creating ipset set with $LINES matches"

if ipset list | grep -q "Name: ipsum"; then
  iptables -D INPUT -m set --match-set ipsum src -j DROP
  ipset flush ipsum
  ipset destroy ipsum
fi
ipset create ipsum hash:ip maxelem $(cat $TMP | grep -v '#' | grep -vE $(cat /etc/resolv.conf | grep '^nameserver' | awk '{print $2}' | sed -z '$ s/\n$//' | tr '\n' '|') | wc -l)

cat $TMP | grep -v '#' | grep -vE $(cat /etc/resolv.conf | grep '^nameserver' | awk '{print $2}' | sed -z '$ s/\n$//' | tr '\n' '|') | cut -f 1 | sed -e 's/^/add ipsum /g' | ipset restore -!
rm $TMP

iptables -I INPUT -m set --match-set ipsum src -j DROP

ipset list | grep -A6 "Name: ipsum"

echo "Updated firewall data"
EOF
chmod 755 /usr/local/bin/ipsum.sh

cat <<'EOF' > /etc/cron.d/ipsum
@reboot /usr/local/bin/ipsum.sh
0 5 * * * /usr/local/bin/ipsum.sh
EOF

# Configure fail2ban

cat <<'EOF' > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 1d
findtime = 15m
maxretry = 3
backend = auto

[sshd]
port = 22
EOF

systemctl restart fail2ban

# Send package-to-upgrade list to journald
cat <<'EOF' > /etc/cron.daily/package-to-upgrade
#!/bin/sh
apt list --upgradable 2>/dev/null | grep -i security | /usr/bin/logger -t package-to-upgrade
EOF
sudo chmod +x /etc/cron.daily/package-to-upgrade

# Install Docker
# This installation is based on https://docs.docker.com/engine/install/ubuntu/ documentation

for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done

install -m 0755 -d /etc/apt/keyrings
rm -f /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

docker info
apt dist-upgrade -y
