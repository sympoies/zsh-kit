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

typeset empty_zdotdir="$tmp_dir/empty-zdotdir"
mkdir -p -- "$empty_zdotdir" || fail "failed to create empty zdotdir"
typeset empty_cache="$tmp_dir/empty-cache"
mkdir -p -- "$empty_cache" || fail "failed to create empty cache dir"
typeset fake_bin="$tmp_dir/bin"
mkdir -p -- "$fake_bin" || fail "failed to create fake bin dir"
print -rl -- '#!/usr/bin/env -S zsh -f' 'print -r -- "[{\"q\":\"Fetched quote.\",\"a\":\"Fetcher\"}]"' >| "$fake_bin/curl" \
  || fail "failed to write curl stub"
print -rl -- '#!/usr/bin/env -S zsh -f' \
  'input="$(cat)"' \
  'case "$*" in' \
  '  *.\[0\].q*) print -r -- "Fetched quote." ;;' \
  '  *.\[0\].a*) print -r -- "Fetcher" ;;' \
  '  *) print -r -- "$input" ;;' \
  'esac' >| "$fake_bin/jq" || fail "failed to write jq stub"
chmod +x "$fake_bin/curl" "$fake_bin/jq" || fail "failed to chmod fetch stubs"

(
  typeset -x ZDOTDIR="$empty_zdotdir"
  typeset -x ZSH_CACHE_DIR="$empty_cache"
  typeset -x ZSH_TOOLS_DIR="$fake_tools"
  path=("$fake_bin" $path)
  unset _LOGIN_QUOTE_EXECUTED 2>/dev/null || true
  source "$QUOTE_SCRIPT" > "$tmp_dir/empty-out.txt" || fail "sourcing quote-init.zsh with empty quotes failed"
)

typeset empty_out=''
empty_out="$(<"$tmp_dir/empty-out.txt")"
[[ "$empty_out" == *'💬 "Stay hungry, stay foolish." — Steve Jobs'* ]] || fail "expected fallback line, got: $empty_out"

typeset -i wait_attempt=0
while (( wait_attempt < 20 )) && [[ ! -s "$empty_zdotdir/assets/quotes.txt" ]]; do
  sleep 0.1
  (( wait_attempt++ ))
done

[[ -s "$empty_zdotdir/assets/quotes.txt" ]] || fail "expected background fetch to create quotes file"
[[ "$(<"$empty_zdotdir/assets/quotes.txt")" == *'"Fetched quote." — Fetcher'* ]] \
  || fail "expected fetched quote in quotes file"
[[ -s "$empty_cache/quotes.timestamp" ]] || fail "expected successful background fetch to update timestamp"

print -r -- "ok"
