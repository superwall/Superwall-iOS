# SuperwallSupport (add-on)

The Support add-on for SuperwallKit (plan decision 42): native in-app chat,
shipped as its own package so apps that don't use Support ship nothing extra.
It never imports SuperwallKit's Swift types; it talks to core through a
Foundation-types bridge (`SWKSupportBridge`, found by class name at configure).

**Status: M1, transport only.** No UI, no bridge yet. Not released.

## The transport

`SupportTransport` speaks `superwall-support/1` (contract:
`paywall-next/packages/inbox-contracts`):

- `POST /v1/sessions` to start, re-run once when a token is refused
- the newest window over HTTP on open, `before=` windows to scroll back
- the live socket (`URLSessionWebSocketTask`, `permessage-deflate` offered by the OS):
  `hello {after, afterId}` → `ready {head}` → backlog → live
- resume from the cursor with `prev` gap checks, duplicates dropped, the tail
  applied as truncate-then-append (UTF-16 offsets) and sealed by its entry
- lenient decoding: unknown entry kinds and keys survive, malformed frames are
  ignored, an undecodable entry still moves the cursor and draws its `text`
- a persisted send queue: one `clientMessageId` per message, retried until the
  server confirms it, so a send lands once across retries and relaunches
- attachments: ask, PUT to the presigned URL, complete

Transport rules from the M0 spike: hold the socket only while foregrounded
(`SupportLifecycleMonitor`); reconnect at once on foreground or
network-available with backoff reset; ping every 10 s with a 5 s deadline,
including during catch-up; probe a surviving socket on foreground; when
`ready.head - cursor` is over 60, close and read HTTP windows instead.

## Tests

```sh
swift test                                                  # fixtures + unit
SUPPORT_FIXTURE_URL=http://localhost:8791 swift test        # + end to end
```

The end-to-end tests need paywall-next's fixture server
(`PORT=8791 pnpm --filter @superwall/inbox-test-client fixture-server`).

Fixtures come from paywall-next with `scripts/sync-fixtures.sh
/path/to/paywall-next [ref]`, which records the source commit in
`Tests/SuperwallSupportTests/Fixtures/SOURCE.json`. Founder-side modules
(change stream, outbox, ingress) are synced but not decoded here.

## Test app

`TestApp/` (XcodeGen) drives the transport on a Simulator or device;
`TestApp/tools/run-sim-scenarios.sh` runs drop-at-every-seq, network cut
(through `tools/cut-proxy.mjs`, since the Simulator has no airplane mode),
background/foreground and far-behind catch-up, and saves each run's log.
