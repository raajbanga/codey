#!/bin/bash
# Runs ON the runner, as root (via SSM Run Command, see runner/SETUP.md).
# Creates the runner key once (/etc/codey-runner/secrets.env, root-only) and
# points Caddy at <elastic-ip>.sslip.io: HTTPS, the X-Runner-Key header, and
# only /api/v2/execute and /api/v2/runtimes. Prints the URL, never the key.
# Rotate the key: delete secrets.env, run this again, then push-secrets.sh.
set -euo pipefail
install -d -m 700 /etc/codey-runner
if [ ! -f /etc/codey-runner/secrets.env ]; then
  TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')
  IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
  umask 077
  printf 'RUNNER_URL=https://%s.sslip.io\nRUNNER_KEY=%s\n' "$(echo "$IP" | tr . -)" "$(openssl rand -hex 32)" > /etc/codey-runner/secrets.env
fi
. /etc/codey-runner/secrets.env
HOST=${RUNNER_URL#https://}

cat > /etc/caddy/Caddyfile <<EOF
$HOST {
    request_body {
        max_size 128KB
    }
    @runner {
        header X-Runner-Key $RUNNER_KEY
        path /api/v2/execute /api/v2/runtimes
    }
    handle @runner {
        reverse_proxy 127.0.0.1:2000
    }
    respond 404
}
EOF
chown root:caddy /etc/caddy/Caddyfile
chmod 640 /etc/caddy/Caddyfile
systemctl reload caddy
echo "Caddy configured for $RUNNER_URL"
