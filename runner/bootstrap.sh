#!/bin/bash
# EC2 user data for the Codey code runner (runner/SETUP.md). Runs once, as
# root, at first boot of Ubuntu 24.04: swap, Docker, Piston + the four
# languages, Caddy. HTTPS and the runner key are set afterwards by
# runner/configure-caddy.sh, once the Elastic IP is attached.
set -euxo pipefail
exec > /var/log/codey-bootstrap.log 2>&1
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get -y -o Dpkg::Options::=--force-confold upgrade

# 4 GB swap: Swift and Java compiles on a 2 GB box.
fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Docker and Caddy apt repositories.
apt-get install -y ca-certificates curl gnupg debian-keyring debian-archive-keyring apt-transport-https
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin caddy
usermod -aG docker ubuntu

# Piston on localhost only; Caddy is the only way in.
mkdir -p /opt/piston
cat > /opt/piston/docker-compose.yml <<'EOF'
services:
  api:
    image: ghcr.io/engineer-man/piston
    container_name: piston_api
    restart: always
    privileged: true            # Isolate needs it to create sandboxes
    ports:
      - "127.0.0.1:2000:2000"
    volumes:
      - ./data/piston/packages:/piston/packages
    tmpfs:
      - /tmp:exec
    environment:
      PISTON_DISABLE_NETWORKING: "true"
      PISTON_RUN_TIMEOUT: "5000"
      PISTON_RUN_CPU_TIME: "5000"
      PISTON_COMPILE_TIMEOUT: "20000"
      PISTON_COMPILE_CPU_TIME: "20000"
      PISTON_OUTPUT_MAX_SIZE: "65536"
      PISTON_MAX_PROCESS_COUNT: "64"
      PISTON_MAX_CONCURRENT_JOBS: "4"
EOF
cd /opt/piston
docker compose up -d
until curl -sf localhost:2000/api/v2/runtimes > /dev/null; do sleep 2; done

for p in "python 3.12.0" "java 15.0.2" "gcc 10.2.0" "swift 5.3.3"; do
  set -- $p
  curl -sf -X POST localhost:2000/api/v2/packages -H 'Content-Type: application/json' \
    -d "{\"language\":\"$1\",\"version\":\"$2\"}"
  echo
done
curl -s localhost:2000/api/v2/runtimes

touch /var/lib/codey-bootstrap.done
