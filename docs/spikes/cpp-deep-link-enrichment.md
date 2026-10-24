# CPP deep-link enrichment forwarding spike

This spike forwards an incoming deep link through the existing enrichment request before Superwall tracks `deepLink_open`. It does not identify a Custom Product Page on its own. The backend must first sync published CPP-to-deep-link mappings from App Store Connect and implement matching.

## Wire contract

The existing `POST /api/v1/enrich` request keeps `user` and `device` and adds optional request-only context:

```json
{
  "user": {},
  "device": {},
  "deep_link": {
    "original_url": "https://myapp.superwall.app/app-link/welcome?ref=campaign",
    "resolved_url": "myapp://welcome?ref=campaign"
  }
}
```

The original URL is the one passed by the app to `Superwall.handleDeepLink`, before Superwall rewrites an app-link URL. Both values preserve query parameters and fragments. The SDK does not normalize them or make any CPP inference. App identity and credentials continue through the existing enrichment transport.

Ordinary enrichment calls omit `deep_link`. The response remains `{ "user": ..., "device": ... }`; request context is not saved in the enrichment response cache.

## Flow

1. The app forwards a URL to `Superwall.handleDeepLink`.
2. Existing cold-start storage retains it until configuration is available.
3. For an ordinary acquisition deep link, the router awaits enrichment with the original and resolved URLs. The HTTP request uses a one-second timeout and no retries.
4. Existing enrichment handling applies response user attributes via `setUserAttributes`.
5. The router tracks the existing `deepLink_open` event with its existing resolved URL. Its placement can now use any returned CPP attributes.
6. An enrichment error still proceeds to step 5.

Return and redemption links retain their early handling. Debugger and local-preview URLs skip acquisition enrichment, including URLs containing preview tokens. The public handler's synchronous return value remains a routing decision; it does not signal completion of enrichment.

## Before production

- Add backend cached catalog lookup and return unambiguous matches in `user`, e.g. `acquisition_product_page_id`. No App Store Connect request belongs in this latency-sensitive path.
- Gate rollout so current production enrichment is not called once more for every deep link before matching exists.
- Decide precedence, expiry and identity-reset behavior for returned attribution. Ambiguous matches must remain unknown.
- Define behavior for overlapping deep links and a user identity change during a request; this spike preserves per-link sequencing but does not serialize independent router tasks.
- The one-second value is an HTTP request timeout, not an end-to-end deadline for device-context collection or the network layer's foreground wait. Define a complete deadline before shipping.
- Superwall-controlled `deepLink_open` placements wait for enrichment. Paywalls independently triggered by the host app or its deep-link delegate do not wait.
- A CPP deep link is only observable if delivered to the app and forwarded to Superwall. This does not establish deferred attribution for every App Store install.

## Tests

The focused Swift Testing suite covers request encoding and omission, original versus resolved URL preservation, enrichment-before-tracking order, failure continuation, and return-link bypass. Existing router and device-helper suites are also run for regression coverage.

Local verification: 70 tests across `DeepLinkEnrichmentTests`, `DeepLinkRouterTests` and `DeviceHelperTests` passed on an iPad (A16), iOS 26.3.1 simulator. The test invocation overrode the generated test target's deployment minimum to iOS 15 and used a local compiler-discovery workaround for an Xcode 26.4 stderr-pipe hang; no build-setting workaround is committed. SwiftLint reports four existing warnings outside the changed code and no new violations.
