# User seeds

Choose whether identified users receive a seed derived from their user ID.

## Overview

`user.seed` is a number from 0 to 99 that can be used in campaign audience filters.
Anonymous users receive a randomly generated seed. To derive a consistent seed from the
ID supplied to `identify(userId:)`, configure ``SuperwallOptions/enableUserIdSeed``:

```swift
let options = SuperwallOptions()
options.enableUserIdSeed = true
Superwall.configure(apiKey: "YOUR_API_KEY", options: options)

// Call when your authentication provider supplies the user's ID.
Superwall.shared.identify(userId: supabaseUserId)
```

The option defaults to `false`, which keeps the existing behavior: the seed is only derived
from the user ID if Superwall has turned this on for your app.

## Identity changes

Set the option before configuring the SDK. On identification with a new ID, the SDK uses the
existing SHA256-based bucketing algorithm. The same ID produces the same bucket across installs
and devices using this algorithm. Multiple IDs can share a bucket. Leading and trailing whitespace
is removed from the ID before hashing.

Identification can change an anonymous user's bucket. Resetting the SDK generates a new anonymous
seed.

The SDK persists the seed. Identifying an already identified user with the same ID returns early,
so enabling this option does not migrate their existing seed, including after an app restart.
Avoid resetting existing users just to change their seed, since resetting also clears user state.

Changing seed behavior can change which audiences match. The seed is an audience variable;
it does not directly select a campaign's experiment variant.
