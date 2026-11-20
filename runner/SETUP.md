# Code runner setup (AWS EC2 + Piston + Caddy)

This is the sandbox that runs the Swift, Python, Java, and C++ that students write in Challenges.

```
App ──HTTPS──▶ Supabase Edge Function `run-challenge` ──HTTPS + X-Runner-Key──▶ Caddy (EC2:443) ──▶ Piston (127.0.0.1:2000)
```

- **Piston** ([engineer-man/piston](https://github.com/engineer-man/piston), MIT) runs each job in an Isolate sandbox: no network, time, process, and file limits.
- **Caddy** provides HTTPS (a free Let's Encrypt certificate for `<ip>.sslip.io`, so no domain needed). It only lets through requests that carry the secret header, and only to `/api/v2/execute` and `/api/v2/runtimes`. Package install and delete can't be reached from outside.
- The app **never** knows this address or key. Only the Edge Function's secrets do.

Total time: about 30–40 minutes, most of it the Swift and Java package downloads.

## What gets created

Values in angle brackets are placeholders: fill in your own and keep the real ones in the team password manager, not in the repo.

| | |
|---|---|
| Region | `<region>`, the one closest to the Supabase project; keep everything in it |
| Instance | `t3.small` (2 vCPU, 2 GB), Ubuntu 24.04, 30 GB gp3 (encrypted), IMDSv2 only, tagged `Name=codey-runner` |
| Address | An Elastic IP, so the URL `https://<a-b-c-d>.sslip.io` never changes |
| Security group | Ports 80 and 443 only. **No SSH**: use SSM |
| Instance role | An EC2 role with only `AmazonSSMManagedInstanceCore` |
| CLI identity | An IAM user with only the EC2, SSM and IAM actions this setup needs, in a named AWS CLI profile. Never root |
| Secrets | On the runner in `/etc/codey-runner/secrets.env` (root-only). Copied to Supabase and GitHub by `runner/push-secrets.sh`. Never in the repo or the app |

## Automated path (recommended)

Same result as the manual steps below, with the AWS CLI and no SSH. Files are in this folder:

- `bootstrap.sh`: EC2 user data. At first boot it does steps 5–8 (swap, Docker, Piston, the four languages) and writes `/var/lib/codey-bootstrap.done`. Log: `/var/log/codey-bootstrap.log`.
- `configure-caddy.sh`: step 9, run through SSM after the Elastic IP is attached. It creates the key once and prints only the URL.
- `push-secrets.sh`: step 11, run on your Mac. It reads the secrets through SSM and sets them in Supabase (`supabase secrets set`) and GitHub (`gh secret set`) without printing them.

1. Profile: `export AWS_PROFILE=<profile> AWS_REGION=<region>` (the scripts default to a profile named `codey` and the profile's own region).
2. Role: `aws iam create-role --role-name <runner-role>` (EC2 trust), `attach-role-policy … AmazonSSMManagedInstanceCore`, `create-instance-profile` + `add-role-to-instance-profile`.
3. Security group with ingress 80 and 443 only (IPv4 and IPv6).
4. `aws ec2 run-instances --image-id <ssm:/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id> --instance-type t3.small --iam-instance-profile Name=<runner-role> --metadata-options HttpTokens=required --user-data file://runner/bootstrap.sh --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=codey-runner}]' …`
5. `allocate-address` + `associate-address`.
6. When `/var/lib/codey-bootstrap.done` exists: `aws ssm send-command --document-name AWS-RunShellScript` with the contents of `configure-caddy.sh`.
7. On your Mac, with the Supabase CLI linked to the project (`supabase link`): `runner/push-secrets.sh`.

Run a shell command on the runner (instead of SSH):

```bash
aws ssm start-session --target <instance-id>
```

(Needs the Session Manager plugin: `brew install --cask session-manager-plugin`.)

> Note: `push-secrets.sh` reads the key through an SSM command, so the key stays in that command's output in SSM history (account admins only) until SSM expires it.

---

## Manual path (console + SSH)

## 1. Launch the instance (AWS console)

1. Sign in to the AWS console. In the top-right region picker, choose the region closest to your Supabase project, and keep it consistent.
2. Go to **EC2 → Instances → Launch instances**.
3. **Name:** `codey-runner`
4. **AMI:** **Ubuntu Server 24.04 LTS**, architecture **64-bit (x86)**. (Piston's image is x86, and 24.04 uses cgroup v2 by default, which Piston needs.)
5. **Instance type:** `t3.small` (2 vCPU, 2 GB). If your account is on the free plan, pick a type the console labels **Free tier eligible** with at least 2 GB of memory. `t3.micro` (1 GB) is too small for the Swift and Java compilers, even with swap.
6. **Key pair:** **Create new key pair**, name `codey-runner`, type RSA, format `.pem`, then **Create**. The file downloads; keep it safe.
7. **Network settings → Edit:**
   - Create a security group named `codey-runner-sg`.
   - Rule 1: **SSH**, port 22, source **My IP**.
   - **Add security group rule:** **HTTPS**, port 443, source **Anywhere (0.0.0.0/0)**.
   - **Add security group rule:** **HTTP**, port 80, source **Anywhere (0.0.0.0/0)** (only for the certificate; Caddy redirects it to HTTPS).
   - Do **not** open port 2000.
8. **Configure storage:** **30 GiB**, **gp3**.
9. **Launch instance.**

## 2. Give it a fixed IP (Elastic IP)

1. **EC2 → Network & Security → Elastic IPs → Allocate Elastic IP address → Allocate.**
2. Select the new IP → **Actions → Associate Elastic IP address** → Instance: `codey-runner` → **Associate**.
3. Write the IP down. Below it's called `RUNNER_IP` (for example `203.0.113.10`, a documentation address).

## 3. Set a cost alarm (do this now, not later)

1. **Billing and Cost Management → Budgets → Create budget → Use a template → Monthly cost budget.**
2. Amount: `10` USD, with your email address as the recipient → **Create budget**.

## 4. Connect over SSH (on your Mac)

```bash
mv ~/Downloads/codey-runner.pem ~/.ssh/ && chmod 400 ~/.ssh/codey-runner.pem
```

```bash
ssh -i ~/.ssh/codey-runner.pem ubuntu@RUNNER_IP
```

Everything from here until step 10 runs **on the server**.

## 5. Update and add swap

```bash
sudo apt-get update && sudo apt-get -y upgrade
```

```bash
sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

Check that cgroup v2 is active (it must print `cgroup2fs`):

```bash
stat -fc %T /sys/fs/cgroup/
```

## 6. Install Docker

```bash
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker ubuntu
```

Log out and back in so the `docker` group applies:

```bash
exit
```

```bash
ssh -i ~/.ssh/codey-runner.pem ubuntu@RUNNER_IP
```

```bash
docker run --rm hello-world
```

## 7. Run Piston

```bash
sudo mkdir -p /opt/piston && sudo chown ubuntu:ubuntu /opt/piston && cd /opt/piston
```

```bash
cat > docker-compose.yml <<'EOF'
services:
  api:
    image: ghcr.io/engineer-man/piston
    container_name: piston_api
    restart: always
    privileged: true            # Isolate needs it to create sandboxes
    ports:
      - "127.0.0.1:2000:2000"   # localhost only; Caddy is the way in
    volumes:
      - ./data/piston/packages:/piston/packages
    tmpfs:
      - /tmp:exec
    environment:
      PISTON_DISABLE_NETWORKING: "true"
      PISTON_RUN_TIMEOUT: "5000"          # ms per run
      PISTON_RUN_CPU_TIME: "5000"
      PISTON_COMPILE_TIMEOUT: "20000"     # Swift compiles slowly
      PISTON_COMPILE_CPU_TIME: "20000"
      PISTON_OUTPUT_MAX_SIZE: "65536"     # bytes of stdout/stderr
      PISTON_MAX_PROCESS_COUNT: "64"
      PISTON_MAX_CONCURRENT_JOBS: "4"     # 2 vCPU box
EOF
```

```bash
docker compose up -d && sleep 5 && curl -s localhost:2000/api/v2/runtimes
```

It prints `[]`, because no languages are installed yet.

## 8. Install the four languages

These versions are the ones the challenges target. Swift and Java are large, so this takes several minutes.

```bash
for p in "python 3.12.0" "java 15.0.2" "gcc 10.2.0" "swift 5.3.3"; do
  set -- $p
  echo "== installing $1 $2"
  curl -s -X POST localhost:2000/api/v2/packages -H 'Content-Type: application/json' \
    -d "{\"language\":\"$1\",\"version\":\"$2\"}"
  echo
done
```

```bash
curl -s localhost:2000/api/v2/runtimes | python3 -m json.tool | grep -E '"(language|version)"'
```

You should see python 3.12.0, java 15.0.2, c++ and c (gcc 10.2.0), and swift 5.3.3.

Smoke test (still on localhost):

```bash
curl -s -X POST localhost:2000/api/v2/execute -H 'Content-Type: application/json' -d '{
  "language": "python", "version": "3.12.0",
  "files": [{"name": "main.py", "content": "print(sum(range(10)))"}]
}'
```

Expect `"stdout":"45\n"` in the reply. Check that networking is blocked (the output must show an error, not HTML):

```bash
curl -s -X POST localhost:2000/api/v2/execute -H 'Content-Type: application/json' -d '{
  "language": "python", "version": "3.12.0",
  "files": [{"name": "main.py", "content": "import urllib.request; print(urllib.request.urlopen(\"https://example.com\").read()[:20])"}]
}'
```

## 9. HTTPS + secret key with Caddy

Install Caddy:

```bash
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update && sudo apt-get install -y caddy
```

Create the key and the hostname, then write the Caddyfile. The heredoc is unquoted on purpose, so `$HOST` and `$RUNNER_KEY` are filled in:

```bash
RUNNER_KEY=$(openssl rand -hex 32)
HOST="$(curl -s https://checkip.amazonaws.com | tr . -).sslip.io"
printf 'RUNNER_URL=https://%s\nRUNNER_KEY=%s\n' "$HOST" "$RUNNER_KEY" > ~/runner-secrets.txt && chmod 600 ~/runner-secrets.txt

sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
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
sudo chown root:caddy /etc/caddy/Caddyfile && sudo chmod 640 /etc/caddy/Caddyfile
sudo systemctl reload caddy
cat ~/runner-secrets.txt
```

Copy the two lines it prints into the team password manager. They're secrets: **never commit them** and never put them in `Config/Secrets.xcconfig` (the app must not have them).

## 10. Test from your Mac

Paste your values:

```bash
RUNNER_URL=https://203-0-113-10.sslip.io
RUNNER_KEY=paste-the-key
```

With the key, you should get the runtimes list:

```bash
curl -s "$RUNNER_URL/api/v2/runtimes" -H "X-Runner-Key: $RUNNER_KEY" | head -c 300; echo
```

Without the key, you should get 404:

```bash
curl -s -o /dev/null -w '%{http_code}\n' "$RUNNER_URL/api/v2/runtimes"
```

With the key, package install should also get 404, because it's blocked from outside:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X POST "$RUNNER_URL/api/v2/packages" -H "X-Runner-Key: $RUNNER_KEY"
```

A full Swift run (the compile takes a few seconds):

```bash
curl -s -X POST "$RUNNER_URL/api/v2/execute" -H "X-Runner-Key: $RUNNER_KEY" -H 'Content-Type: application/json' -d '{
  "language": "swift", "version": "5.3.3",
  "files": [{"name": "main.swift", "content": "print([3,1,2].sorted())"}]
}'
```

## 11. Give the secrets to the Edge Function

From the repo, on your Mac, with the Supabase CLI logged in and linked:

```bash
supabase secrets set RUNNER_URL="$RUNNER_URL" RUNNER_KEY="$RUNNER_KEY"
```

```bash
supabase secrets list
```

(Or use the dashboard: **Edge Functions → Secrets**.) CI needs no runner secrets: it runs `scripts/challenges.ts check` and the judge tests offline. The live check of every reference solution runs from your Mac: `runner/with-secrets.sh deno run -A scripts/challenges.ts validate`. (`push-secrets.sh` also copies the two values to GitHub Actions secrets; pass `--no-github` to skip that.)

---

## Day-to-day

| Task | Command (on the server) |
|---|---|
| Status | `docker ps` · `systemctl status caddy` |
| Piston logs | `docker logs --tail 100 piston_api` |
| Restart Piston | `cd /opt/piston && docker compose restart` |
| Update Piston | `cd /opt/piston && docker compose pull && docker compose up -d` (packages persist in `./data`) |
| Rotate the key | Run step 9 again (new `RUNNER_KEY`), then step 11 |
| Disk use | `df -h /` |

- Ubuntu installs security updates automatically (`unattended-upgrades`). Reboot monthly: `sudo reboot`, and both services come back on their own.
- **Stopping the instance** (EC2 → Instance state → Stop) pauses compute billing. The Elastic IP is billed while the instance is stopped, but it keeps the URL the same. Start it again before a demo and run the step 10 checks.
- **If the runner is down**, the Edge Function returns `runner_down` and the app shows "The code runner is offline, try again later". Drills and everything else keep working.
- **Your IP changed and SSH hangs:** EC2 → Security Groups → `codey-runner-sg` → edit the SSH rule → **My IP**.
