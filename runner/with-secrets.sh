#!/bin/bash
# Runs a command with RUNNER_URL and RUNNER_KEY in its environment, read from
# the runner through SSM (never printed). Example:
#   runner/with-secrets.sh deno run -A scripts/challenges.ts validate
set -euo pipefail
export AWS_PROFILE=${AWS_PROFILE:-codey}  # region: AWS_REGION or the profile's own
INSTANCE=$(aws ec2 describe-instances --filters Name=tag:Name,Values=codey-runner Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
CMD=$(aws ssm send-command --instance-ids "$INSTANCE" --document-name AWS-RunShellScript \
  --comment "codey: read runner secrets" --parameters 'commands=["cat /etc/codey-runner/secrets.env"]' \
  --query Command.CommandId --output text)
aws ssm wait command-executed --command-id "$CMD" --instance-id "$INSTANCE"
set -a
eval "$(aws ssm get-command-invocation --command-id "$CMD" --instance-id "$INSTANCE" --query StandardOutputContent --output text | grep -E '^RUNNER_(URL|KEY)=[A-Za-z0-9:/._-]+$')"
set +a
exec "$@"
