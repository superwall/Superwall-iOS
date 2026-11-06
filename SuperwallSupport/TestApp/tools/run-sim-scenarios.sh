#!/usr/bin/env bash
# Runs the transport scenarios on a booted iOS Simulator against the fixture
# server behind cut-proxy.mjs, and saves each run's app log.
#   run-sim-scenarios.sh <udid> <out-dir>
# Needs: fixture server on :8791, cut-proxy on :8792 (control :8793).
set -uo pipefail
UDID="$1"; OUT="$2"; B=com.superwall.support.transporttest
BASE=http://localhost:8792; DIRECT=http://localhost:8791
mkdir -p "$OUT"

applog() { echo "$(xcrun simctl get_app_container "$UDID" $B data)/Documents/support-transport.log"; }
launch() { xcrun simctl launch --terminate-running-process "$UDID" $B -baseURL $BASE "$@" >/dev/null; }
token() { grep -o 'token tok_[A-Z0-9]*' "$(applog)" | awk '{print $2}'; }
conv() { grep -o 'conversation conv_[A-Z0-9]*' "$(applog)" | awk '{print $2}'; }
post() { # post N messages straight to the server, as another device would
  local n=$1 prefix=$2 t c; t=$(token); c=$(conv)
  for i in $(seq 1 "$n"); do
    curl -s -o /dev/null -X POST "$DIRECT/v1/conversations/$c/messages" -H "authorization: Bearer $t" \
      -H 'content-type: application/json' -d "{\"clientMessageId\":\"$prefix-$i\",\"text\":\"host $i\"}"
  done
}
background() { xcrun simctl launch "$UDID" com.apple.Preferences >/dev/null; }
foreground() { xcrun simctl launch "$UDID" $B >/dev/null; }
save() { cp "$(applog)" "$OUT/$1.log"; echo "== $1"; grep -E "verify|state (live|idle|offline)" "$OUT/$1.log" | tail -4; }

# 1. The transport cuts its own socket after every new seq while 20 sends land.
launch -apiKey pk_test_ios_every -dropEverySeq 1 -sendBurst 20 -verifyEvery 2
sleep 16; save 1-drop-every-seq

# 2. The network path dies mid-burst for 6 s (connections reset, new ones refused).
curl -s localhost:8793/restore >/dev/null
launch -apiKey pk_test_ios_cut -sendBurst 15 -verifyEvery 2
sleep 0.4; curl -s localhost:8793/cut; sleep 6; curl -s localhost:8793/restore
sleep 10; save 2-network-cut

# 3. Background while another device posts 10 messages, then foreground.
launch -apiKey pk_test_ios_bg -verifyEvery 2
sleep 3; background; sleep 2; post 10 bg; sleep 3; foreground
sleep 6; save 3-background-foreground

# 4. Far behind: the client holds 2, then 75 land while backgrounded, more than the
#    socket replay cap (60): one HTTP catch-up. (A client holding nothing loads the
#    newest window instead.)
launch -apiKey pk_test_ios_far -verifyEvery 2
sleep 3; post 2 held; sleep 1; background; sleep 1; post 75 far; foreground
sleep 8; save 4-far-behind-http-catchup

# 5. A paced fixture script (tail streaming) with the socket cut after every seq.
launch -apiKey pk_fixture_future-kinds -dropEverySeq 1 -verifyEvery 2
sleep 12; save 5-fixture-future-kinds
