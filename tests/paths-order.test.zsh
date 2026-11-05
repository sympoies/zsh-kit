#!/usr/bin/env -S zsh -f
setopt nounset pipe_fail

typeset root="${0:A:h:h}" zsh_bin="$(command -v zsh)" tmp=''
tmp="$(mktemp -d)" || exit 1
{
  typeset home="$tmp/home with spaces" zdot="$tmp/config"
  mkdir -p "$home/.linuxbrew/bin" "$home/.linuxbrew/sbin" "$home/.cargo/bin" "$home/.local/nils-cli/bin" "$home/fnm/bin" "$zdot/scripts/_internal" "$zdot/bootstrap"
  cp "$root/.zshenv" "$root/.zshrc" "$zdot/"
  cp "$root/scripts/_internal/paths.exports.zsh" "$zdot/scripts/_internal/"
  print -r -- 'zsh_env::is_true() { return 1; }' > "$zdot/bootstrap/00-preload.zsh"
  : > "$zdot/bootstrap/bootstrap.zsh"

  # Obtain the complete candidate set on this system, then place every entry
  # after the caller's chosen entry for an actual interactive startup.
  typeset candidates=''
  candidates="$(env -i HOME="$home" ZDOTDIR="$zdot" FNM_MULTISHELL_PATH="$home/fnm" PATH=/usr/bin "$zsh_bin" -c 'print -r -- $PATH')" || exit 1
  typeset inherited="/selected/bin:$home/.local/nils-cli/bin:$candidates"
  typeset actual=''
  actual="$(env -i HOME="$home" ZDOTDIR="$zdot" FNM_MULTISHELL_PATH="$home/fnm" PATH="$inherited" "$zsh_bin" -i -c '
    [[ "$PATH" == "$1" ]] || { print -u2 -r -- "startup reordered inherited PATH: $PATH"; exit 1; }
    unset _ZSH_INTERNAL_PATHS_EXPORTS_SOURCED
    source "$ZDOTDIR/scripts/_internal/paths.exports.zsh"
    source "$ZDOTDIR/.zshrc"
    [[ "$PATH" == "$1" ]] || { print -u2 -r -- "repeat sourcing reordered PATH: $PATH"; exit 1; }
    "$2" -c '\''[[ "$PATH" == "$1" ]]'\'' zsh "$1" || exit 1
  ' zsh "$inherited" "$zsh_bin" 2>&1)" || { print -u2 -r -- "$actual"; exit 1; }

  # Each Homebrew entry is considered independently, including paths with spaces.
  actual="$(env -i HOME="$home" ZDOTDIR="$zdot" PATH="$home/.linuxbrew/bin:/usr/bin" "$zsh_bin" -c 'print -r -- $PATH')" || exit 1
  [[ "$actual" == *"$home/.linuxbrew/sbin"* && "$actual" == *"$home/.linuxbrew/bin:/usr/bin" ]] || { print -u2 -r -- "independent bin/sbin insertion failed: $actual"; exit 1; }
  actual="$(env -i HOME="$home" ZDOTDIR="$zdot" PATH="$home/.linuxbrew/sbin:/usr/bin" "$zsh_bin" -c 'print -r -- $PATH')" || exit 1
  [[ "$actual" == *"$home/.linuxbrew/bin"* && "$actual" == *"$home/.linuxbrew/sbin:/usr/bin" ]] || { print -u2 -r -- "independent sbin/bin insertion failed: $actual"; exit 1; }
  print -r -- OK
} always {
  rm -rf -- "$tmp"
}
