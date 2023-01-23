# Superwall Events

Events that are automatically tracked by the SDK and power the charts in the Superwall dashboard.

## Overview

The SDK automatically tracks the events specified in ``SuperwallEvent``. Some of these can be used to present paywalls by adding them as events to a campaign.

Event Name | Action | Can Present Paywalls
--- | --- | ---
`app_install` | When the SDK is configured for the first time, or directly after calling ``Superwall/logOut()`` or ``Superwall/reset()``. | *Yes*
`app_launch` | When the app is launched from a cold start. | *Yes*
`session_start` | When the app is opened either from a cold start, or after at least 30 seconds since last `app_close`. | *Yes* (recommended)
`deepLink_open` | When a user opens the app via a deep link. | *Yes*
`first_seen` | When the user, regardless of whether they've logged in, was first seen on the app. | *no*
`app_close` | Anytime the app leaves the foreground. | *no*
`app_open` | Anytime the app enters the foreground. | *no*
`paywall_open` | When a paywall is opened. | *no*
`paywall_close` | When a paywall is closed (either by user interaction or do to a transaction succeeding). | *no*
`trigger_fire` | When a tracked event triggers a paywall. | *no*
`transaction_start` | When the payment sheet is displayed to the user. | *no*
`transaction_fail` | When the payment sheet fails to complete a transaction (ignores user canceling the transaction). | *no*
`transaction_abandon` | When the user cancels a transaction. | *no*
`transaction_complete` | When the user completes checkout in the payment sheet and any product was "purchased". | *no*
`transaction_restore` | When the user successfully restores their purchases. | *no*
`subscription_start` | When the user successfully completes a transaction for a subscription product with no introductory offers. | *no*
`freeTrial_start` | When the user successfully completes a transaction for a subscription product with an introductory offer. | *no*
`nonRecurringProduct_purchase` | When the user purchased a non recurring product. | *no*
`paywallResponseLoad_start` | When a paywall's request to Superwall's servers has started. | *no*
`paywallResponseLoad_fail` | When a paywall's request to Superwall's servers has failed. | *no*
`paywallResponseLoad_complete` | When a paywall's request to Superwall's servers is complete. | *no*
`paywallResponseLoad_notFound` | When a paywall's request to Superwall's servers returned a 404 error. | *no*
`paywallWebviewLoad_start` | When a paywall's website begins to load. | *no*
`paywallWebviewLoad_fail` | When a paywall's website fails to load. | *no*
`paywallWebviewLoad_timeout` | When the loading of a paywall's website times out. | *no*
`paywallWebviewLoad_complete` | When a paywall's website completes loading. | *no*
`paywallProductsLoad_start` | When the request to load the paywall's products started. | *no*
`paywallProductsLoad_fail` | When the request to load the paywall's products failed. | *no*
`paywallProductsLoad_complete` | When the request to load the paywall's products completed. | *no*
`paywallPresentationFail_userIsSubscribed` | When trying to present the paywall but the user is subscribed. | *no*
`paywallPresentationFail_holdout` | When trying to present the paywall but the user is in a holdout group. | *no*
`paywallPresentationFail_eventNotFound` | When trying to present the paywall but the event provided was not found in any campaign on the dashboard. | *no*
`paywallPresentationFail_debuggerLaunched` | When trying to present the paywall but the debugger is launched. | *no*
`paywallPresentationFail_alreadyPresented` | When trying to present the paywall but there's already a paywall presented. | *no*
`paywallPresentationFail_noPresenter` | When trying to present the paywall but there isn't a view to present the paywall on. | *no*
`paywallPresentationFail_noPaywallViewController` | When trying to present the paywall but there was an error getting the paywall view controller. | *no*
