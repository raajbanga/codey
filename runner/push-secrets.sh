#!/bin/bash
# Run on your Mac (not the runner): copies RUNNER_URL and RUNNER_KEY from the
# runner into the Supabase Edge Function secrets and the GitHub Actions
# secrets, without printing the key. Needs the `codey` AWS profile (or
# AWS_PROFILE), a Supabase CLI that is logged in and linked to the project
# (`supabase login`, `supabase link`; or set SUPABASE_PROJECT_REF), and gh.
#
#   runner/push-secrets.sh            # Supabase + GitHub
#   runner/push-secrets.sh --no-github
set -euo pipefail
export AWS_PROFILE=${AWS_PROFILE:-codey}  # region: AWS_REGION or the profile's own
INSTANCE=$(aws ec2 describe-instances --filters Name=tag:Name,Values=codey-runner Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)

CMD=$(aws ssm send-command --instance-ids "$INSTANCE" --document-name AWS-RunShellScript \
  --comment "codey: read runner secrets" --parameters 'commands=["cat /etc/codey-runner/secrets.env"]' \
  --query Command.CommandId --output text)
aws ssm wait command-executed --command-id "$CMD" --instance-id "$INSTANCE"

ENV_FILE=$(mktemp)
trap 'rm -f "$ENV_FILE"' EXIT
aws ssm get-command-invocation --command-id "$CMD" --instance-id "$INSTANCE" \
  --query StandardOutputContent --output text > "$ENV_FILE"
grep -q '^RUNNER_KEY=' "$ENV_FILE" || { echo "No secrets on the runner; run configure-caddy.sh first." >&2; exit 1; }

REF=${SUPABASE_PROJECT_REF:-$(cat supabase/.temp/project-ref 2>/dev/null || true)}
[ -n "$REF" ] || { echo "Run supabase link (or set SUPABASE_PROJECT_REF) first." >&2; exit 1; }
supabase secrets set --project-ref "$REF" --env-file "$ENV_FILE" --yes 2>&1 | grep -v deprecated
if [ "${1:-}" != "--no-github" ]; then
  gh secret set --env-file "$ENV_FILE"
fi
echo "Done: RUNNER_URL and RUNNER_KEY set (values not shown)."
