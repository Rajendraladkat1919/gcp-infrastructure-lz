#!/usr/bin/env bash
# Prints a JSON array of the stages a change touches, in apply order.
# Usage: changed-stages.sh [BASE_REF]   (no BASE_REF = every stage)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

base="${1:-}"
changed=""
run_all=false
if [[ -z "$base" ]]; then
  run_all=true
else
  changed="$(git diff --name-only "$base" HEAD)"
  if grep -qE '^(modules/|config/stages\.txt|\.github/(workflows|actions)/|\.terraform-version)' <<<"$changed"; then
    run_all=true
  fi
fi

selected=""
while IFS= read -r stage; do
  [[ -z "$stage" || "$stage" == \#* ]] && continue
  if [[ "$run_all" == true ]] || grep -q "^${stage}/" <<<"$changed"; then
    selected+="${stage}"$'\n'
  fi
done <config/stages.txt

printf '%s' "$selected" | jq -R -s -c 'split("\n") | map(select(length > 0))'
