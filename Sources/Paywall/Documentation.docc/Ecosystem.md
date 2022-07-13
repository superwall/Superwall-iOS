# Understanding How Superwall Works

An overview of how Superwall works in relation to your app.

## Overview

Superwall is built on 3 core principles:

1. Triggers
2. Rules
3. Paywalls

When your app executes a **trigger**, evaluate a **rule** to decide which **paywall** to show the user.

Triggers and Rules are grouped in a concept we call **Campaigns**.

## Rapid Iteration

Paywalls and Campaigns are all defined in the [Superwall Dashboard](https://superwall.com/dashboard). If you don't already have a Superwall account, you can [sign up for free](https://superwall.com/sign-up).

Integrating the Paywall SDK into your app is usually the last time you'll have to write paywall related code.

This allows you to iterate on 5 key aspects of your monetization flow, without shipping app updates:

- Design
- Text / Copy
- Placement
- Pricing
- Discounts
- Paywalls

Superwall uses a script called **Paywall.js** to turn websites into paywall templates. The Paywall SDK loads these websites inside a `UIWebView`, and executes javascript on them to replace text and template product information. This gives you the flexibility to turn any design into a paywall and update it remotely.

Since building websites can be tedious, Superwall maintains a [clonable Webflow template](https://webflow.com/website/45-Paywall-Elements?ref=showcase-search&searchValue=superwall) including ~50 of the most prominent paywall elements we've seen across thousands of apps.

## Rules

Rules allow you to conditionally show a paywall to a user. For example, you may want to only show users paywalls if they have no remaining credits or if their account is over 24 hours old.

Rule evaluations happen client side, so no network requests are fired to determine whether or not to show a paywall.

## Triggers

A trigger is an analytics event you can wire up to specific rules. The Paywall SDK listens for these analytics events and evaluates their rules to determine whether or not to show a paywall when the trigger is fired.

## Inner workings of the SDK

The following diagram describes the inner workings of the Paywall SDK and your app:

![How Superwall works](apiDiagram.png)


Read <doc:GettingStarted> to learn how to integrate the SDK into your app.
