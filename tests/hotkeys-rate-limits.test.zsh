#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr HOTKEYS="$REPO_ROOT/scripts/interactive/hotkeys.zsh"

fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "FAIL: $*"
  exit 1
}

assert_eq() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset expected="$1" actual="$2" context="$3"
  if [[ "$actual" != "$expected" ]]; then
    print -u2 -r -- "Expected: $expected"
    print -u2 -r -- "Actual  : $actual"
    print -u2 -r -- "Context : $context"
    return 1
  fi
}

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t hotkeys-rate-limits-test.XXXXXX)" || fail "mktemp failed"

{
  typeset log="$tmp_dir/cli.log"
  typeset cli=''
  : >| "$log"

  for cli in claude-cli codex-cli; do
    {
      print -r -- '#!/usr/bin/env -S zsh -f'
      print -r -- 'print -r -- "${0:t} ${(j: :)argv}" >>| "${HOTKEYS_STUB_LOG:?}"'
    } >| "$tmp_dir/$cli"
    chmod 755 "$tmp_dir/$cli"
  done

  typeset output='' rc=0 logged=''

  # Source hotkeys.zsh in a clean shell, then run the Claude widget with `zle` stubbed out.
  output="$(PATH="$tmp_dir:$PATH" HOTKEYS_STUB_LOG="$log" zsh -f -c '
    tab_before="$(bindkey "^I")"
    source "$1" || exit 1
    bindkey "^Y"
    bindkey "^U"
    [[ "$(bindkey "^I")" == "$tab_before" ]] && print -r -- "tab-unchanged"
    zle() { return 0 }
    BUFFER="pending command" CURSOR=7
    claude-cli-rate-limits-widget || exit 1
    print -r -- "buffer=${BUFFER} cursor=${CURSOR}"
  ' hotkeys-test "$HOTKEYS" 2>&1)"
  rc=$?
  logged="$(command cat -- "$log")"

  assert_eq 0 "$rc" "hotkeys.zsh should load and the Claude widget should run" || fail "$output"
  assert_eq '"^Y" claude-cli-rate-limits-widget' "${${(f)output}[1]}" "Ctrl+Y binding" || fail "$output"
  assert_eq '"^U" codex-cli-rate-limits-async-widget' "${${(f)output}[2]}" "Ctrl+U binding" || fail "$output"
  assert_eq 'tab-unchanged' "${${(f)output}[3]}" "Ctrl+I (Tab) binding" || fail "$output"
  assert_eq 'buffer=pending command cursor=7' "${${(f)output}[4]}" "buffer restored after widget" || fail "$output"
  assert_eq 'claude-cli diag rate-limits --all --async' "$logged" "Claude widget argv" || fail "$logged"

  print -r -- "OK"
} always {
  [[ -n "$tmp_dir" && -d "$tmp_dir" ]] && command rm -rf -- "$tmp_dir"
}
