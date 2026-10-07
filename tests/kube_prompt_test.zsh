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

# --- Starship `when` conditions -----------------------------------------------
# Read both conditions from the real config, so the test follows any edit.
when_of() {
  sed -n "/^\[custom\.$1\]/,/^$/s/^when = '\(.*\)'$/\1/p" \
    "$repo_root/config/starship.toml"
}
local when_prod=$(when_of kube_prod) when_kube=$(when_of kube)
[[ -n "$when_prod" && -n "$when_kube" ]] \
  && pass "found both when conditions in starship.toml" \
  || fail "could not read when conditions from starship.toml"

print 'current-context: aks_prod_app_westeurope_05' > "$work_dir/prod.yaml"
print 'current-context: aks_preprod_app_westeurope_05' > "$work_dir/preprod.yaml"

# expect_modules <description> <kubeconfig> <expected visible modules>
expect_modules() {
  local shown=()
  # Starship discards stderr from `when`, e.g. grep's missing-file error.
  KUBECONFIG="$2" zsh -f -c "$when_prod" 2>/dev/null && shown+=(kube_prod)
  KUBECONFIG="$2" zsh -f -c "$when_kube" 2>/dev/null && shown+=(kube)
  [[ "${shown[*]}" == "$3" ]] && pass "$1" || fail "$1: got '${shown[*]}', want '$3'"
}

expect_modules "prod context shows only the red module" "$work_dir/prod.yaml" kube_prod
expect_modules "non-prod context shows only the cyan module" "$work_dir/preprod.yaml" kube
expect_modules "missing kubeconfig shows neither module" "$work_dir/none.yaml" ''

# --- Result -------------------------------------------------------------------
if (( failures > 0 )); then
  print "\n$failures assertion(s) failed"
  exit 1
fi
print "\nall kube-prompt tests passed"
