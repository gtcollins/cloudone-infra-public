#!/usr/bin/env bash
# Run Terraform for one environment, using envs/<env>/ values.
#
#   ./scripts/tf.sh dev init                 # connect to dev's state bucket
#   ./scripts/tf.sh dev plan -out=dev.tfplan
#   ./scripts/tf.sh dev apply dev.tfplan
#   ./scripts/tf.sh prod output
#
# Each environment gets its own .terraform cache, so switching between dev and
# prod never needs `init -reconfigure`.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
usage="usage: $0 <env> <terraform command> [args...]   envs: $(ls "$root/envs" | tr '\n' ' ')"

env="${1:-}"
cmd="${2:-}"
[ -n "$env" ] && [ -n "$cmd" ] || { echo "$usage" >&2; exit 2; }
shift 2

envdir="$root/envs/$env"
[ -f "$envdir/terraform.tfvars" ] || { echo "No such environment: envs/$env" >&2; echo "$usage" >&2; exit 2; }

export TF_DATA_DIR="$root/.terraform-envs/$env"
tf=(terraform -chdir="$root/stack")

case "$cmd" in
  init)
    exec "${tf[@]}" init -backend-config="$envdir/backend.hcl" "$@" ;;
  apply)
    # A saved plan already contains its variables.
    if [ $# -gt 0 ] && [ -f "$root/stack/$1" -o -f "$1" ]; then
      exec "${tf[@]}" apply "$@"
    fi
    exec "${tf[@]}" apply -var-file="$envdir/terraform.tfvars" "$@" ;;
  plan|destroy|refresh|import|console)
    exec "${tf[@]}" "$cmd" -var-file="$envdir/terraform.tfvars" "$@" ;;
  *)
    exec "${tf[@]}" "$cmd" "$@" ;;
esac
