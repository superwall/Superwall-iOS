# Config decoding prewarm experiment

On a fresh app process without a usable cached config, decoding a small representative Config while the network is in flight can move first-use model/decoder initialization out of the response-processing tail. It adds a small discarded decode; it does not eliminate CPU work.

## Recorded simulator evidence

The prototype linked the real SDK models at `5970c3a2937f4c6f403b42bd2cede7f88c0a7d58`. It ran on an arm64 iPhone 17 / iOS 26.3 Simulator on an Apple M2 Max. Twenty distinct app processes alternated baseline/prewarm across five repetitions per arm/sample. An actual localhost HTTP/gzip server injected 80 ms initial delay, without bandwidth shaping, TLS or a CDN.

The prototype resumed its URLSessionDataTask, then decoded a bundled 3,830-byte fixture on a utility queue. The fixture contained one rule/paywall and two App Store products. The fixture model was discarded without SDK state, cache, events, StoreKit or WebView operations. Real response processing never awaited the warmup. Readiness included actual Config construction, configuration indexing/variant helpers and first static paywall lookup, not complete Superwall.configure or rendered paywall readiness.

| Median milliseconds, n=5 | Baseline JSON | Concurrent prewarm |
| --- | ---: | ---: |
| Real public example, 28 KB: request to processed config/lookup | 157.32 | 104.77 |
| Example: decode after response body completion | 51.73 | 5.73 |
| Derived 524 KB / 200-paywall graph: request to processed config/lookup | 161.29 | 115.42 |
| Derived graph: decode after response body completion | 65.68 | 22.58 |

All 20 model fingerprints matched across arms. Warmup took approximately 58 ms elapsed and finished before response-body completion in all ten enabled runs. The derived graph clones real shapes with rewritten valid references and repeated content; it is not a production traffic percentile.

[Machine-readable summary and observations](config-decoding-prewarm.json) preserve the measurements. These establish the prototype's initialization-overlap benefit, not a separately measured speedup of this PR's production integration. The production fixture uses synthetic identifiers and URLs and exercises the same representative model path. Unit tests separately validate that fixture and the production scheduling/request integration.

## Limits and production policy

- Simulator timings are subject to host scheduling; physical-device CPU, energy, allocations, peak memory and frame responsiveness were not measured. This is not evidence of a one-second SDK startup gain.
- A very fast response or CPU-constrained phone may leave less overlap and increase contention. The 58 ms warmup duration is elapsed time, not a measurement of additional CPU usage.
- The fixture does not cover every optional model, product kind or future schema case. Keep fixture decode coverage tests current as the Config contract changes.
- A usable cached Config is already decoded before a network refresh. Prewarm only for a cache miss, at most once per process, after starting a request, using a separate decoder on a utility queue. Never apply or persist its result.
- Preserve request retries, errors, cancellation and timeouts. Normal requests retain the existing URLSession async path.

## Verification

The Swift Testing suites exercise the actual embedded fixture, concurrent once scheduling, execution off the main thread, cache-miss gating, request-before-warmup ordering, response independence and cancellation/timeout behavior. Run them on an iOS simulator using the generated SuperwallKit project; see CLAUDE.md for repository test and lint commands. Quantifying production performance further requires paired fresh-process app runs with equal network conditions, including fast-response cases and older physical phones.
