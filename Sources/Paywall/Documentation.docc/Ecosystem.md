# The Relationship Between the SDK, the Dashboard and the Presented Paywall

An overview of the Superwall ecosystem.

## Overview

The following diagram gives an overview of how the Superwall ecosystem works:

![The relationship between the SDK, the dashboard, and the presented paywall](apiDiagram.png)

## Superwall Dashboard

The [Superwall Dashboard](https://superwall.com/dashboard) is your control center. You can configure paywalls and triggers, view analytics, manage users and more on there. If you don't already have an account, you can [sign up for free](https://superwall.com/sign-up). The dashboard interacts with the Superwall API to store your configurations.

## Superwall API

The API is the go-between that all our services use to communicate with each other. When you configure the SDK, you pass it your Public API Key, which you retrieve from the dashboard settings. The SDK uses this to be able to communicate with the API to load your paywalls and triggers, ready for presentation. You can also send user variables and events to the API that will appear in the dashboard.

## Paywall Template

All paywalls are webpages that act as templates for you to configure in the dashboard. The easiest way to create a paywall webpage is with [Webflow](https://webflow.com). We have created a Webflow project with dozens of common paywall elements for you to quickly get up and running. For more info on how to build a paywall with Webflow, [see here](https://docs.superwall.com/docs/building-paywalls-with-webflow).

In the header of the paywall, you add a link to a script we provide called Paywall.js. Then, you tag elements on the webpage, such as text or buttons, with [data tags](https://docs.superwall.com/docs/data-tags). These allow Paywall.js to interpret feedback and transmit information to and from the SDK.

In addition, when you configure a paywall on the dashboard, you input its URL and the dashboard instantly recognizes the data tags you've provided. From there, you can edit the text of all tagged items. This allows for quick iteration of paywall text. For example, you could create one paywall webpage but run an A/B test with two different configurations of the paywall in your app.

> Important: Paywall.js is available to Superwall customers subject to the terms of the subscription agreement between Superwall and the customer, and is not available as an open-source project.


## Templated Paywall

All of this information is abstracted away from users of your app. They just see the templated paywall presented in a `UIWebView`. Paywall.js makes sure that this paywall feels native. Which paywall they see depends on your settings in the dashboard. When a user taps on an interactive element in the paywall that has a valid data tag, the appropriate delegate methods are called. It's up to you as the developer to implement the delegate and handle events that happen on the paywall, such as purchasing and restoring.

## Superwall SDK

Read <doc:GettingStarted> to learn how to integrate the SDK into your app.
