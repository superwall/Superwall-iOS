# Triggering a Paywall

Show a specific paywall in your app in response to an analytical event.

## Overview

Triggers enable you to retroactively decide where and when to show a specific paywall in your app.

You configure a trigger via the dashboard, specifying which paywall will show in response to an analytical event sent via the SDK.

You can send your own analytical events, or you can use a ``Paywall/Paywall/StandardEvent`` that the SDK automatically tracks. Specifically: `app_install`, app_launch, and session_start.

The SDK recognizes when it is sending an event that's tied to an active trigger in the dashboard and will display the corresponding paywall.



## Topics

### <!--@START_MENU_TOKEN@-->Group<!--@END_MENU_TOKEN@-->

- <!--@START_MENU_TOKEN@-->``Symbol``<!--@END_MENU_TOKEN@-->
