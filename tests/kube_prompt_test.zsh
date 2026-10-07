#!/usr/bin/env zsh
# Tests for bin/kube-prompt.
#
# Self-contained: a mock `kubectl` is placed first in PATH and prints the
# "<context>\t<namespace>" line that `kubectl config view --minify` would,
# so no kubeconfig or cluster access is needed.
#
# Run: zsh tests/kube_prompt_test.zsh
# Exit code: 0 if all assertions pass, 1 otherwise.

emulate -L zsh
set -u

local repo_root="${0:A:h:h}"
local work_dir
work_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$work_dir"' EXIT

local failures=0
pass() { print "  ok: $1" }
fail() { print "FAIL: $1"; failures=$((failures + 1)) }

# --- Mock `kubectl` -----------------------------------------------------------
# Prints $MOCK_KUBECTL with escapes expanded, as kubectl's jsonpath output
# expands {"\t"}.
mkdir -p "$work_dir/bin"
cat > "$work_dir/bin/kubectl" <<'EOF'
#!/bin/sh
printf '%b' "$MOCK_KUBECTL"
EOF
chmod +x "$work_dir/bin/kubectl"

# expect <description> <mock output> <expected prompt text>
expect() {
  local out
  out=$(MOCK_KUBECTL="$2" PATH="$work_dir/bin:$PATH" "$repo_root/bin/kube-prompt")
  [[ "$out" == "$3" ]] && pass "$1" || fail "$1: got '$out', want '$3'"
}

# --- Shortening ---------------------------------------------------------------
expect "prod AKS context keeps env and team" \
  'aks_prod_app_westeurope_05\taks-prod-app-westeurope-05--architecture' \
  'prod · architecture'
expect "preprod AKS context keeps env and team" \
  'aks_preprod_app_westeurope_05\taks-preprod-app-westeurope-05--fleet' \
  'preprod · fleet'
expect "empty namespace shows env only" \
  'aks_dev_bat_northeurope_03\t' \
  'dev'
expect "non-AKS context prints as-is" \
  'rancher-desktop\t' \
  'rancher-desktop'
expect "namespace without -- prints as-is" \
  'rancher-desktop\tdefault' \
  'rancher-desktop · default'

# --- Failure paths ------------------------------------------------------------
# No current context: kubectl prints nothing, so the prompt module hides.
expect "no current context prints nothing" '' ''

# kubectl not installed: only system dirs on PATH, error stays silent.
out=$(PATH="/usr/bin:/bin" "$repo_root/bin/kube-prompt" 2>&1)
[[ -z "$out" ]] \
  && pass "missing kubectl prints nothing" \
  || fail "missing kubectl printed: $out"

# --- Result -------------------------------------------------------------------
if (( failures > 0 )); then
  print "\n$failures assertion(s) failed"
  exit 1
fi
print "\nall kube-prompt tests passed"
