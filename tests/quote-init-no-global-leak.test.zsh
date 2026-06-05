#!/usr/bin/env -S zsh -f

# No `nounset`: quote-init.zsh (like weather.zsh) is only sourced in an
# interactive shell, which does not set nounset, and its run-once guard reads
# $_LOGIN_QUOTE_EXECUTED unguarded by design.
setopt pipe_fail

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr QUOTE_SCRIPT="$REPO_ROOT/bootstrap/quote-init.zsh"

fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "FAIL: $*"
  exit 1
}

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t zsh-kit-quote-init-test.XXXXXX)" || fail "mktemp failed"

# Fake ZDOTDIR with a quotes asset.
typeset fake_zdotdir="$tmp_dir/zdotdir"
mkdir -p -- "$fake_zdotdir/assets" || fail "failed to create assets dir"
print -r -- '"Test quote." — Tester' >| "$fake_zdotdir/assets/quotes.txt" || fail "failed to write quotes"

# Fake cache dir with a FRESH timestamp so the background refresh is skipped (no network).
typeset fake_cache="$tmp_dir/cache"
mkdir -p -- "$fake_cache" || fail "failed to create cache dir"
print -r -- "$(date +%s)" >| "$fake_cache/quotes.timestamp" || fail "failed to seed timestamp"

# Fake tools dir with a deterministic emoji command.
typeset fake_tools="$tmp_dir/tools"
mkdir -p -- "$fake_tools" || fail "failed to create tools dir"
print -rl -- '#!/usr/bin/env -S zsh -f' 'print -rn -- "🤖"' >| "$fake_tools/random_emoji_cmd.zsh" \
  || fail "failed to write emoji stub"
chmod +x "$fake_tools/random_emoji_cmd.zsh" || fail "failed to chmod emoji stub"

typeset -x ZDOTDIR="$fake_zdotdir"
typeset -x ZSH_CACHE_DIR="$fake_cache"
typeset -x ZSH_TOOLS_DIR="$fake_tools"
unset _LOGIN_QUOTE_EXECUTED 2>/dev/null || true

# Source in the CURRENT shell (not a subshell) so any leaked variable would persist
# here; capture stdout to a file instead of via command substitution.
source "$QUOTE_SCRIPT" > "$tmp_dir/out.txt" || fail "sourcing quote-init.zsh failed"
typeset out=''
out="$(<"$tmp_dir/out.txt")"

# Banner content still renders.
[[ "$out" == *'📜 "Test quote." — Tester'* ]] || fail "expected local quote line, got: $out"
[[ "$out" == *"Thinking shell initialized"* ]] || fail "expected banner line, got: $out"

# The emoji helper remains defined for interactive use.
(( $+functions[emoji] )) || fail "emoji function should remain defined"

# Throwaway banner state must NOT leak into the surrounding shell scope.
typeset leak=''
for leak in now last_fetch quote_line quotes_file timestamp_file fetch_interval \
            QUOTES_FILE QUOTES_TIMESTAMP_FILE QUOTE_FETCH_INTERVAL; do
  if typeset -p "$leak" >/dev/null 2>&1; then
    fail "login banner leaked variable into shell scope: $leak"
  fi
done

print -r -- "ok"
