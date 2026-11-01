#!/usr/bin/env bash
# NetRadar parallel micro-probe helper
# Target argument: $1 (default: 103.10.124.1 Valve Singapore)
set -u

TARGET="${1:-103.10.124.1}"
GW=$(ip route show default 2>/dev/null | awk '{print $3; exit}')

GW_TMP=$(mktemp)
DNS_TMP=$(mktemp)
GAME_TMP=$(mktemp)
trap 'rm -f "$GW_TMP" "$DNS_TMP" "$GAME_TMP"' EXIT INT TERM

if [ -n "$GW" ]; then
  (ping -c 1 -W 1 "$GW" 2>/dev/null | sed -nE 's/.*time=([0-9.]+) ms/\1/p' > "$GW_TMP") &
else
  echo "none" > "$GW_TMP" &
fi

(ping -c 1 -W 1 "1.1.1.1" 2>/dev/null | sed -nE 's/.*time=([0-9.]+) ms/\1/p' > "$DNS_TMP") &
(ping -c 1 -W 1 "$TARGET" 2>/dev/null | sed -nE 's/.*time=([0-9.]+) ms/\1/p' > "$GAME_TMP") &

# Wi-Fi link information via nmcli (use --rescan no to avoid channel hops and latency spikes)
WIFI_RAW=$(nmcli -t -f active,ssid,freq,signal,rate dev wifi list --rescan no 2>/dev/null | grep '^yes:' | head -n 1)

wait

GW_MS=$(cat "$GW_TMP" 2>/dev/null)
DNS_MS=$(cat "$DNS_TMP" 2>/dev/null)
GAME_MS=$(cat "$GAME_TMP" 2>/dev/null)

rm -f "$GW_TMP" "$DNS_TMP" "$GAME_TMP"

[ -z "$GW_MS" ] && GW_MS="none"
[ -z "$DNS_MS" ] && DNS_MS="none"
[ -z "$GAME_MS" ] && GAME_MS="none"

SSID="none"
FREQ="0"
SIGNAL="0"
RATE="0"

if [ -n "$WIFI_RAW" ]; then
  IFS=':' read -r _active _ssid _freq _signal _rate <<< "$WIFI_RAW"
  [ -n "$_ssid" ] && SSID="$_ssid"
  # Extract numeric freq (e.g. "5180 MHz" -> "5180")
  _freq_num=$(echo "$_freq" | tr -dc '0-9')
  [ -n "$_freq_num" ] && FREQ="$_freq_num"
  # Extract numeric signal percentage
  _sig_num=$(echo "$_signal" | tr -dc '0-9')
  [ -n "$_sig_num" ] && SIGNAL="$_sig_num"
  # Extract rate in Mbit/s
  _rate_clean=$(echo "$_rate" | sed -E 's/([0-9.]+).*/\1/')
  [ -n "$_rate_clean" ] && RATE="$_rate_clean"
fi

SSID="${SSID//|/-}"

echo "${GW_MS}|${DNS_MS}|${GAME_MS}|${SSID}|${FREQ}|${SIGNAL}|${RATE}"
