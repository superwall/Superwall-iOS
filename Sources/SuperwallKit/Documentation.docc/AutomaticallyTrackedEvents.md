# Automatically Tracked Events

Events that are automatically tracked via the SDK and power the charts in the Superwall dashboard.

## Overview

The SDK automatically tracks the events specified in ``SuperwallEvent``. Some of these can be used to present paywalls by adding them as events to a campaign.

Event Name | Action | Can Present Paywalls
--- | --- | ---
`app_install` | When the SDK is configured for the first time, or directly after calling ``Superwall/reset()`` | *Yes*
`app_launch` | When the app is launched from a cold start | *Yes*
`session_start` | When the app is opened either from a cold start, or after at least 30 seconds since last `app_close`. | *Yes* (recommended)
`first_seen` | When the user, regardless of whether they've logged in, was first seen on the app | *no*
`app_close` | Anytime the app leaves the foreground | *no*
`app_open` | Anytime the app enters the foreground | *no*
`app_launch` | Anytime the app enters the foreground | *no*
`paywall_open` | When a paywall is opened | *no*
`paywall_close` | When a paywall is closed (either by user interaction or do to a transaction succeeding) | *no*
`transaction_start` | When the payment sheet is displayed to the user | *no*
`transaction_fail` | When the payment sheet fails to complete a transaction (ignores user canceling the transaction) | *no*
`transaction_abandon` | When the user cancels a transaction | *no*
`transaction_complete` | When the user completes checkout in the payment sheet and any product was "purchased" | *no*
`subscription_start` | When the user successfully completes a transaction for a subscription product with no introductory offers | *no*
`freeTrial_start` | When the user successfully completes a transaction for a subscription product with an introductory offer | *no*
`transaction_restore` | When the user successfully restores their purchases | *no*
`nonRecurringProduct_purchase` | When the user purchased a non recurring product | *no*
`paywallResponseLoad_start` | When a paywall's request to Superwall's servers has started | *no*
`paywallResponseLoad_fail` | When a paywall's request to Superwall's servers has failed | *no*
`paywallResponseLoad_complete` | When a paywall's request to Superwall's servers is complete | *no*
`paywallWebviewLoad_start` | When a paywall's website begins to load | *no*
`paywallWebviewLoad_fail` | When a paywall's website fails to load | *no*
`paywallWebviewLoad_timeout` | When the loading of a paywall's website times out | *no*
`paywallWebviewLoad_complete` | When a paywall's website completes loading | *no*