#!/usr/bin/env bash
# Lists every value you still need to customize for CloudOne.
# Exit code 1 while anything is left, 0 when you're done.
#
#   ./scripts/check-customization.sh
#
# When you replace a value, also delete its "🛑 CHANGE ME" comment.
set -euo pipefail
cd "$(dirname "$0")/.."

pattern='CHANGE ME|REPLACE_WITH|^[[:space:]]*[A-Za-z_]+[[:space:]]*=[[:space:]]*"TODO"'

# Search Terraform files only; skip provider caches and pure comment lines
# (banners and explanations), so each hit is a real value to change.
matches=$(grep -rnE --include='*.tf' --include='*.tfvars' --include='*.hcl' -e "$pattern" . 2>/dev/null \
  | grep -vE '/\.terraform(-envs)?/|\.terraform\.lock\.hcl' \
  | awk '{ line = $0; sub(/^[^:]*:[^:]*:/, "", line); if (line !~ /^[[:space:]]*#/) print }' \
  || true)

if [ -z "$matches" ]; then
  echo "✅ Nothing left to customize. Run 'terraform plan' in envs/dev next."
  exit 0
fi

count=$(printf '%s\n' "$matches" | wc -l | tr -d ' ')
echo "🛑 $count line(s) still need your CloudOne values:"
echo
printf '%s\n' "$matches" | sed 's|^\./||'
echo
echo "👉 See CUSTOMIZE.md for what to put in each one."
exit 1
