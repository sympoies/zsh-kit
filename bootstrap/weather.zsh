# zsh_weather::format_today_json
# Format a `weather-cli today --output json` envelope into a one-line banner.
# Usage: zsh_weather::format_today_json <json>
# Output: "<emoji> <city> · <condition>  <min>~<max>°C[  ☔ <pct>%]"
# Notes:
# - Requires jq; returns non-zero when jq is missing, the envelope is not
#   `ok`, or required fields cannot be extracted.
# - The rain segment is omitted when the precipitation probability is 0.
# - Unknown WMO weather codes fall back to the envelope's `summary_zh` text.
zsh_weather::format_today_json() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset json="${1-}"
  [[ -n "$json" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  typeset fields=''
  fields=$(print -r -- "$json" | jq -r '
    select(.ok == true) | .result as $r | $r.forecast[0] as $f
    | [ $r.location.name,
        ($f.weather_code | tostring),
        ($f.temp_min_c | round | tostring),
        ($f.temp_max_c | round | tostring),
        (($f.precip_prob_max_pct // 0) | tostring),
        ($f.summary_zh // "") ]
    | join("\u001f")
  ' 2>/dev/null) || return 1
  [[ -n "$fields" ]] || return 1

  typeset -a parts=()
  parts=("${(@ps:\x1f:)fields}")
  (( ${#parts[@]} >= 5 )) || return 1

  typeset city="${parts[1]}" code="${parts[2]}" tmin="${parts[3]}" tmax="${parts[4]}" rain="${parts[5]}"
  typeset summary="${parts[6]-}"
  [[ -n "$city" && "$tmin" == (-|)<-> && "$tmax" == (-|)<-> ]] || return 1

  # WMO weather code → banner emoji + English label.
  typeset icon='' label=''
  case "$code" in
    0) icon='☀️'; label='Clear' ;;
    1) icon='🌤'; label='Mostly clear' ;;
    2) icon='⛅'; label='Partly cloudy' ;;
    3) icon='☁️'; label='Overcast' ;;
    45|48) icon='🌫'; label='Fog' ;;
    51|53|55|56|57) icon='🌦'; label='Drizzle' ;;
    61|63|65|66|67) icon='🌧'; label='Rain' ;;
    71|73|75|77) icon='❄️'; label='Snow' ;;
    80|81|82) icon='🌦'; label='Showers' ;;
    85|86) icon='🌨'; label='Snow showers' ;;
    95|96|99) icon='⛈'; label='Thunderstorm' ;;
    *) icon='🌡'; label="${summary:-Weather}" ;;
  esac

  typeset line="$icon $city · $label  ${tmin}~${tmax}°C"
  if [[ "$rain" == <-> ]] && (( rain > 0 )); then
    line+="  ☔ ${rain}%"
  fi

  print -r -- "$line"
  return 0
}

# Prevent double execution
[[ -n "$_LOGIN_WEATHER_EXECUTED" ]] && return
export _LOGIN_WEATHER_EXECUTED=true

typeset -r WEATHER_URL="${ZSH_WEATHER_URL:-https://wttr.in/?0}"
typeset -i WEATHER_FETCH_INTERVAL=${ZSH_WEATHER_INTERVAL:-3600}
typeset -r WEATHER_CACHE_FILE="${ZSH_CACHE_DIR}/weather.txt"
typeset -r WEATHER_TIMESTAMP_FILE="${ZSH_CACHE_DIR}/weather.timestamp"

[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR"

typeset -i now=${EPOCHSECONDS:-0}
if (( now == 0 )); then
  now=$(date +%s)
fi
typeset -i last_fetch=0

if [[ -r "$WEATHER_TIMESTAMP_FILE" ]]; then
  typeset timestamp_content=''
  IFS=$'\n' read -r timestamp_content < "$WEATHER_TIMESTAMP_FILE"
  [[ -n "$timestamp_content" ]] && last_fetch=$timestamp_content
fi

typeset -i fetch_needed=0
if [[ ! -s "$WEATHER_CACHE_FILE" ]]; then
  fetch_needed=1
elif (( now - last_fetch >= WEATHER_FETCH_INTERVAL )); then
  fetch_needed=1
fi

if (( fetch_needed )); then
  typeset weather_output=''
  typeset -i weather_fetched=0

  # Prefer the native weather-cli (nils-cli) when available and a city is configured;
  # otherwise fall back to wttr.in (IP-based location, zero config).
  # The JSON path renders a compact one-line banner (no source/freshness meta);
  # if jq or JSON parsing is unavailable, keep weather-cli's human output.
  if command -v weather-cli >/dev/null 2>&1 && [[ -n "${ZSH_WEATHER_CITY-}" ]]; then
    typeset weather_json=''
    if weather_json=$(weather-cli today --city "$ZSH_WEATHER_CITY" --output json 2>/dev/null) \
      && weather_output=$(zsh_weather::format_today_json "$weather_json"); then
      weather_fetched=1
    elif weather_output=$(weather-cli today --city "$ZSH_WEATHER_CITY" 2>/dev/null); then
      weather_fetched=1
    fi
  fi

  if (( ! weather_fetched )); then
    if weather_output=$(curl -fsS --max-time 4 "$WEATHER_URL"); then
      weather_fetched=1
    fi
  fi

  if (( weather_fetched )); then
    typeset tmp_file="${WEATHER_CACHE_FILE}.tmp.$$"
    printf "%s\n" "$weather_output" >| "$tmp_file"
    mv -f "$tmp_file" "$WEATHER_CACHE_FILE"
    printf "%s\n" "$now" >| "$WEATHER_TIMESTAMP_FILE"
  else
    printf "%s\n" "$now" >| "$WEATHER_TIMESTAMP_FILE"
  fi
fi

printf "\n"

if [[ -s "$WEATHER_CACHE_FILE" ]]; then
  cat -- "$WEATHER_CACHE_FILE"
else
  print -r -- "Weather report unavailable."
fi
