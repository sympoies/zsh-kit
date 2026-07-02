# Prevent double execution
[[ -n "$_LOGIN_QUOTE_EXECUTED" ]] && return
export _LOGIN_QUOTE_EXECUTED=true

# emoji
# Print a random emoji (used by the login banner).
# Usage: emoji
# Notes:
# - Delegates to `$ZSH_TOOLS_DIR/random_emoji_cmd.zsh`.
emoji() {
  "$ZSH_TOOLS_DIR/random_emoji_cmd.zsh"
  return 0
}

# zsh_quote::login_banner
# Print a local quote and, when the cache is stale, refresh it in the background.
# Usage: zsh_quote::login_banner
# Notes:
# - State is kept function-local so the login banner does not leak variables into
#   the interactive shell.
# - The background refresh appends to `$ZDOTDIR/assets/quotes.txt` (gitignored)
#   and is throttled by `$ZSH_CACHE_DIR/quotes.timestamp`.
zsh_quote::login_banner() {
  emulate -L zsh
  setopt pipe_fail

  typeset quotes_file="$ZDOTDIR/assets/quotes.txt"
  typeset timestamp_file="$ZSH_CACHE_DIR/quotes.timestamp"
  typeset -i fetch_interval=3600  # seconds (1 hour)

  mkdir -p -- "${quotes_file:h}" "$ZSH_CACHE_DIR" 2>/dev/null || true

  typeset -i now=0 last_fetch=0
  now=$(date +%s)
  [[ -f "$timestamp_file" ]] && last_fetch=$(<"$timestamp_file")

  # Show a local quote first
  typeset quote_line=''
  if [[ -f "$quotes_file" && -s "$quotes_file" ]]; then
    quote_line=$(shuf -n 1 "$quotes_file")
    printf "\n📜 %s\n" "$quote_line"
  else
    printf "\n💬 \"Stay hungry, stay foolish.\" — Steve Jobs\n"
  fi

  # Decide whether to fetch a new quote
  if [[ ! -s "$quotes_file" ]] || (( now - last_fetch > fetch_interval )); then
    (
      nohup bash -c '
        quote_json=$(curl -s --max-time 2 "https://zenquotes.io/api/random")
        quote=$(printf "%s" "$quote_json" | jq -r ".[0].q" 2>/dev/null)
        author=$(printf "%s" "$quote_json" | jq -r ".[0].a" 2>/dev/null)

        if [[ -n "$quote" && "$quote" != "null" && -n "$author" && "$author" != "null" ]]; then
          if printf "\"%s\" — %s\n" "$quote" "$author" >> "'"$quotes_file"'"; then
            tail -n 100 "'"$quotes_file"'" > "'"$quotes_file"'.tmp" && \
              mv "'"$quotes_file"'.tmp" "'"$quotes_file"'" && \
              date +%s > "'"$timestamp_file"'"
          fi
        fi
      ' &> /dev/null &
    ) >/dev/null 2>&1
  fi

  printf "%s  Thinking shell initialized. Expect consequences...\n" "$(emoji)"
}

zsh_quote::login_banner
