#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr WEATHER_SCRIPT="$REPO_ROOT/bootstrap/weather.zsh"

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
  return 0
}

[[ -f "$WEATHER_SCRIPT" ]] || fail "missing script: $WEATHER_SCRIPT"

if ! command -v jq >/dev/null 2>&1; then
  print -r -- "SKIP (jq not installed)"
  exit 0
fi

# Source only the formatter: the run-once guard stops the banner side effects.
typeset -g _LOGIN_WEATHER_EXECUTED=true
source "$WEATHER_SCRIPT"

(( $+functions[zsh_weather::format_today_json] )) || \
  fail "zsh_weather::format_today_json not defined after sourcing weather.zsh"

typeset -r FIXTURE_DRIZZLE='{"schema_version":"cli-envelope@v1","command":"weather.today","ok":true,"result":{"period":"today","location":{"name":"Taipei","latitude":25.05306,"longitude":121.52639},"timezone":"Asia/Taipei","forecast":[{"date":"2026-06-03","weather_code":51,"summary_zh":"毛毛雨","temp_min_c":24.8,"temp_max_c":35.3,"precip_prob_max_pct":59}],"source":"open_meteo","fetched_at":"2026-06-03T15:19:33Z","freshness":{"status":"live","key":"city-taipei","ttl_secs":1800,"age_secs":0}}}'

typeset -r FIXTURE_CLEAR_NO_RAIN='{"ok":true,"result":{"location":{"name":"Taipei"},"forecast":[{"date":"2026-06-04","weather_code":0,"summary_zh":"晴","temp_min_c":22.4,"temp_max_c":30.6,"precip_prob_max_pct":0}]}}'

typeset -r FIXTURE_NOT_OK='{"ok":false,"error":{"code":"NILS_WEATHER_001","message":"missing location input"}}'

# 1) Drizzle: emoji + city + label, rounded temps, rain percent shown.
typeset line=''
line="$(zsh_weather::format_today_json "$FIXTURE_DRIZZLE")" || fail "formatter returned non-zero for drizzle fixture"
assert_eq '🌦  Taipei  25~35°C  ☔ 59%  Drizzle' "$line" "drizzle fixture formatting" || fail "drizzle output mismatch"

# 2) Clear day with 0% rain: the rain segment is omitted.
line="$(zsh_weather::format_today_json "$FIXTURE_CLEAR_NO_RAIN")" || fail "formatter returned non-zero for clear fixture"
assert_eq '☀️  Taipei  22~31°C  Clear' "$line" "clear fixture omits rain segment" || fail "clear output mismatch"

# 3) Error envelope: non-zero return, no output.
if line="$(zsh_weather::format_today_json "$FIXTURE_NOT_OK" 2>/dev/null)"; then
  fail "formatter should fail on ok=false envelope (got: $line)"
fi

# 4) Empty input: non-zero return.
if line="$(zsh_weather::format_today_json '' 2>/dev/null)"; then
  fail "formatter should fail on empty input (got: $line)"
fi

print -r -- "OK"
