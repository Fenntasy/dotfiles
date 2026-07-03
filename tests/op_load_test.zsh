#!/usr/bin/env zsh
# Tests for zsh/functions/op_load.
#
# Self-contained: a mock `op` CLI is placed first in PATH, so no 1Password
# account or real vault is needed. Each case sources op_load in a clean
# subshell (`zsh -f`) to prove it works without any of our zshrc options
# (extendedglob in particular is set inside the function, not inherited).
#
# Run: zsh tests/op_load_test.zsh
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

# --- Mock `op` CLI -----------------------------------------------------------
# `whoami` always succeeds (pretend we're signed in). `read` returns a value
# per reference, including a hostile one full of shell metacharacters and a
# multi-line one — op_load must treat both as opaque data, never as code.
mkdir -p "$work_dir/bin"
cat > "$work_dir/bin/op" <<EOF
#!/bin/sh
case "\$1" in
  whoami) exit 0 ;;
  read)
    case "\$2" in
      op://vault/item/field) echo "RESOLVED_SECRET" ;;
      op://vault/item/evil) echo '\$(touch $work_dir/pwned) \`touch $work_dir/pwned\`; touch $work_dir/pwned' ;;
      op://vault/item/spaces) echo "value with spaces" ;;
      op://vault/item/multiline) printf -- '-----BEGIN KEY-----\nAAAA==\n-----END KEY-----\n' ;;
      *) echo "op read: not found" >&2; exit 1 ;;
    esac ;;
esac
EOF
chmod +x "$work_dir/bin/op"

# --- Template covering every parser branch -----------------------------------
# - plain KEY=op://ref             -> must be exported (not just a shell param)
# - export KEY="op://ref" (quoted) -> export prefix and quotes tolerated
# - blank line and # comment       -> ignored
# - hostile vault value            -> stored literally, never executed
# - value with spaces              -> preserved whole
# - multi-line value (PEM-style)   -> exported intact, not truncated
# - line that isn't KEY=op://ref   -> skipped; warning shows line number only
cat > "$work_dir/secrets.env" <<'EOF'
PLAIN_VAR=op://vault/item/field
export EXPORTED_VAR="op://vault/item/field"

# comment
EVIL_VAR=op://vault/item/evil
SPACED=op://vault/item/spaces
MULTI=op://vault/item/multiline
LITERAL=super-sensitive-not-a-ref
EOF

# --- Happy path: every reference lands in child-process environment ----------
local out
out=$(cd "$work_dir" && PATH="$work_dir/bin:$PATH" zsh -f -c '
  source "'"$repo_root"'/zsh/functions/op_load"
  op_load secrets.env 2>/dev/null || { print "LOAD_FAILED"; exit 1 }
  # printenv runs in a child process: proves the vars were exported,
  # not merely assigned as shell parameters.
  print "plain=$(printenv PLAIN_VAR)"
  print "exported=$(printenv EXPORTED_VAR)"
  print "spaced=$(printenv SPACED)"
  print "evil=$(printenv EVIL_VAR)"
  print "multilines=$(( $(printenv MULTI | wc -l) ))"
  print "literal=${LITERAL:-unset}"
  [[ -o extendedglob ]] && print "OPTION_LEAK"
')
[[ "$out" == *"plain=RESOLVED_SECRET"* ]] \
  && pass "plain KEY=op://ref is exported" \
  || fail "plain reference not exported: $out"
[[ "$out" == *"exported=RESOLVED_SECRET"* ]] \
  && pass "export prefix and quoted ref tolerated" \
  || fail "export-prefixed quoted ref mishandled: $out"
[[ "$out" == *"spaced=value with spaces"* ]] \
  && pass "value containing spaces survives intact" \
  || fail "spaced value mangled: $out"

# The hostile value must appear verbatim in the environment...
[[ "$out" == *'evil=$(touch'* ]] \
  && pass "hostile value stored literally" \
  || fail "hostile value missing or altered: $out"
# ...and must never have been executed as shell code.
[[ ! -e "$work_dir/pwned" ]] \
  && pass "hostile value never executed (no injection)" \
  || fail "command injection: hostile vault value was executed"

# Multi-line secret: all three lines exported under one key, no truncation,
# and the continuation lines never become variables of their own.
[[ "$out" == *"multilines=3"* ]] \
  && pass "multi-line secret exported intact" \
  || fail "multi-line secret truncated: $out"

# A non-reference line must be skipped, not exported.
[[ "$out" == *"literal=unset"* ]] \
  && pass "non-reference line not exported" \
  || fail "literal line leaked into environment: $out"

# op_load sets extendedglob for its own parsing only.
[[ "$out" != *"OPTION_LEAK"* ]] \
  && pass "shell options don't leak to caller" \
  || fail "extendedglob leaked into calling shell"

# --- Malformed-line warning must not echo line content ------------------------
out=$(cd "$work_dir" && PATH="$work_dir/bin:$PATH" zsh -f -c '
  source "'"$repo_root"'/zsh/functions/op_load"
  op_load secrets.env 2>&1 >/dev/null
')
[[ "$out" == *"skipping malformed line 8"* ]] \
  && pass "malformed line warned with its line number" \
  || fail "no line-numbered warning: $out"
[[ "$out" != *"super-sensitive"* ]] \
  && pass "warning never echoes line content" \
  || fail "warning leaked line content to stderr: $out"

# --- Failure paths ------------------------------------------------------------
out=$(cd "$work_dir" && PATH="$work_dir/bin:$PATH" zsh -f -c '
  source "'"$repo_root"'/zsh/functions/op_load"
  # One unresolvable reference must fail the whole load: values are
  # collected before anything is exported, so no half-loaded env.
  printf "GOOD=op://vault/item/field\nBAD=op://vault/item/nope\n" > fail.env
  op_load fail.env 2>/dev/null && print "NO_ERROR"
  [[ -n "${GOOD:-}" ]] && print "HALF_LOADED"
  op_load missing.env 2>&1 | grep -q "cannot read" && print "missing_ok"
')
[[ "$out" != *"NO_ERROR"* ]] \
  && pass "failed op read returns nonzero" \
  || fail "failed op read did not propagate error"
[[ "$out" != *"HALF_LOADED"* ]] \
  && pass "failed load leaves environment untouched" \
  || fail "environment polluted after failed load"
[[ "$out" == *"missing_ok"* ]] \
  && pass "unreadable template file reports an error" \
  || fail "missing template file not reported"

# --- Result -------------------------------------------------------------------
if (( failures > 0 )); then
  print "\n$failures assertion(s) failed"
  exit 1
fi
print "\nall op_load tests passed"
