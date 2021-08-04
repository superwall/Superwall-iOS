//
//  File.swift
//  
//
//  Created by Brian Anglin on 8/3/21.
//

import Foundation
let paywall = """

<!DOCTYPE html>
<!-- saved from url=(0059)https://app.fitnessai.com/signup/?paywall=true&user_id=1234 -->
<html lang="en">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />

    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"
    />
    <title>FitnessAI — Sign Up</title>
    <link rel="stylesheet" href="./index.css" />
    <script type="text/javascript" async="" src="./qv6x5fs4"></script>
    <script async="" src="./uwt.js"></script>
    <script async="" src="./fbevents.js"></script>
    <script type="text/javascript" async="" src="./mixpanel-2-latest.min.js"></script>
    <script src="./vue.min.js"></script>
    <script src="./v3"></script>
    <script type="text/javascript">
      // Bootstrap staffbar here...

      var consoleOutput = []
      var originalConsoleLog = console.log

      // Put the log lines in the console-output div if it exists
      function updateConsoleLog() {
        var element = document.getElementById("console-output")
        if (element) {
          element.innerText = consoleOutput.join("\n")
        }
      }

      function fakeConsoleLog() {
        // Create a string from the args and push it to the array
        // This just turns the "array-like" arguments object to a real array
        var args = Array.prototype.slice.call(arguments)
        var line = ["-"]
          .concat(
            args.map((arg) => {
              let result
              try {
                return arg.toString()
              } catch (e) {
                console.error(e)
              }
              return ""
            })
          )
          .join(" ")
        consoleOutput.push(line)
        updateConsoleLog()

        // Actually call the real console.log
        // Weird syntax but basically just calls the real console.log
        originalConsoleLog.apply(null, arguments)
      }

      // Replace the native console.log with our wrapper so we can see
      // the output in the page
      console.log = fakeConsoleLog

      // If all console.logs happened before the dom was ready, force an update
      document.addEventListener("DOMContentLoaded", updateConsoleLog)
      // console.log('Script in head loaded');
    </script>

    <script>
      // console.log("yoooooooooooooooooo")
    </script>
    <!-- start first promoter -->

    <script>
      ;(function (w) {
        w.fpr =
          w.fpr ||
          function () {
            w.fpr.q = w.fpr.q || []
            w.fpr.q[arguments[0] == "set" ? "unshift" : "push"](arguments)
          }
      })(window)
      fpr("init", { cid: "0r9d98bz" })
      fpr("click")
    </script>
    <script src="./fpr.js" async=""></script>

    <script src="./../../runtime/entrypoint.js?23234fewfew" async></script>
    <!-- end first promoter -->

    <!-- start mixpanel -->

    <script>
      ;(function (c, a) {
        if (!a.__SV) {
          var b = window
          try {
            var d,
              m,
              j,
              k = b.location,
              f = k.hash
            d = function (a, b) {
              return (m = a.match(RegExp(b + "=([^&]*)"))) ? m[1] : null
            }
            f &&
              d(f, "state") &&
              ((j = JSON.parse(decodeURIComponent(d(f, "state")))),
              "mpeditor" === j.action &&
                (b.sessionStorage.setItem("_mpcehash", f),
                history.replaceState(j.desiredHash || "", c.title, k.pathname + k.search)))
          } catch (n) {}
          var l, h
          window.mixpanel = a
          a._i = []
          a.init = function (b, d, g) {
            function c(b, i) {
              var a = i.split(".")
              2 == a.length && ((b = b[a[0]]), (i = a[1]))
              b[i] = function () {
                b.push([i].concat(Array.prototype.slice.call(arguments, 0)))
              }
            }
            var e = a
            "undefined" !== typeof g ? (e = a[g] = []) : (g = "mixpanel")
            e.people = e.people || []
            e.toString = function (b) {
              var a = "mixpanel"
              "mixpanel" !== g && (a += "." + g)
              b || (a += " (stub)")
              return a
            }
            e.people.toString = function () {
              return e.toString(1) + ".people (stub)"
            }
            l =
              "disable time_event track track_pageview track_links track_forms track_with_groups add_group set_group remove_group register register_once alias unregister identify name_tag set_config reset opt_in_tracking opt_out_tracking has_opted_in_tracking has_opted_out_tracking clear_opt_in_out_tracking start_batch_senders people.set people.set_once people.unset people.increment people.append people.union people.track_charge people.clear_charges people.delete_user people.remove".split(
                " "
              )
            for (h = 0; h < l.length; h++) c(e, l[h])
            var f = "set set_once union unset remove delete".split(" ")
            e.get_group = function () {
              function a(c) {
                b[c] = function () {
                  call2_args = arguments
                  call2 = [c].concat(Array.prototype.slice.call(call2_args, 0))
                  e.push([d, call2])
                }
              }
              for (
                var b = {},
                  d = ["get_group"].concat(Array.prototype.slice.call(arguments, 0)),
                  c = 0;
                c < f.length;
                c++
              )
                a(f[c])
              return b
            }
            a._i.push([b, d, g])
          }
          a.__SV = 1.2
          b = c.createElement("script")
          b.type = "text/javascript"
          b.async = !0
          b.src =
            "undefined" !== typeof MIXPANEL_CUSTOM_LIB_URL
              ? MIXPANEL_CUSTOM_LIB_URL
              : "file:" === c.location.protocol &&
                "//cdn.mxpnl.com/libs/mixpanel-2-latest.min.js".match(/^\\/\\//)
              ? "https://cdn.mxpnl.com/libs/mixpanel-2-latest.min.js"
              : "//cdn.mxpnl.com/libs/mixpanel-2-latest.min.js"
          d = c.getElementsByTagName("script")[0]
          d.parentNode.insertBefore(b, d)
        }
      })(document, window.mixpanel || [])
      mixpanel.init("97a33c904012b7f68000ac5aa92564be", { batch_requests: true })
    </script>

    <!-- end mixpanel -->

    <!-- start fb verif -->

    <meta name="facebook-domain-verification" content="qbxks27vhq20mx8usuqydrh93tjlvl" />

    <!-- end fb verif -->

    <!-- start fb pixel -->

    <script>
      !(function (f, b, e, v, n, t, s) {
        if (f.fbq) return
        n = f.fbq = function () {
          n.callMethod ? n.callMethod.apply(n, arguments) : n.queue.push(arguments)
        }
        if (!f._fbq) f._fbq = n
        n.push = n
        n.loaded = !0
        n.version = "2.0"
        n.queue = []
        t = b.createElement(e)
        t.async = !0
        t.src = v
        s = b.getElementsByTagName(e)[0]
        s.parentNode.insertBefore(t, s)
      })(window, document, "script", "https://connect.facebook.net/en_US/fbevents.js")
      fbq("init", "274248070188673")
      fbq("track", "PageView")
    </script>
    <noscript
      ><img
        height="1"
        width="1"
        style="display: none"
        src="https://www.facebook.com/tr?id=274248070188673&ev=PageView&noscript=1"
    /></noscript>

    <!-- end fb pixel -->

    <!-- start hotjar -->
    <!-- <script>
            (function(h,o,t,j,a,r){
                h.hj=h.hj||function(){(h.hj.q=h.hj.q||[]).push(arguments)};
                h._hjSettings={hjid:2220083,hjsv:6};
                a=o.getElementsByTagName('head')[0];
                r=o.createElement('script');r.async=1;
                r.src=t+h._hjSettings.hjid+j+h._hjSettings.hjsv;
                a.appendChild(r);
            })(window,document,'https://static.hotjar.com/c/hotjar-','.js?sv=');
        </script> -->
    <!-- end hotjar -->

    <script src="./index.js"></script>

    <script src="./platform.js" defer=""></script>

    <style type="text/css">
      div.eapps-widget {
        position: relative;
      }
      div.eapps-widget.eapps-widget-show-toolbar:before {
        position: absolute;
        content: "";
        display: block;
        bottom: 0;
        top: 0;
        left: 0;
        right: 0;
        pointer-events: none;
        border: 1px solid transparent;
        transition: border 0.3s ease;
        z-index: 1;
      }
      .eapps-widget-toolbar {
        position: absolute;
        top: -32px;
        left: 0;
        right: 0;
        display: block;
        z-index: 99999;
        padding-bottom: 4px;
        transition: all 0.3s ease;
        pointer-events: none;
        opacity: 0;
      }
      .eapps-widget:hover .eapps-widget-toolbar {
        opacity: 1;
        pointer-events: auto;
      }
      .eapps-widget-toolbar a {
        text-decoration: none;
        box-shadow: none !important;
      }
      .eapps-widget-toolbar-panel {
        border-radius: 6px;
        background-color: #222;
        color: #fff;
        display: -ms-inline-flexbox;
        display: inline-flex;
        -ms-flex-align: center;
        align-items: center;
        top: 0;
        position: relative;
        transition: all 0.3s ease;
        opacity: 0;
        overflow: hidden;
        -webkit-backface-visibility: hidden;
        backface-visibility: hidden;
        box-shadow: 0 0 0 1px hsla(0, 0%, 100%, 0.2);
        height: 28px;
      }
      .eapps-widget:hover .eapps-widget-toolbar-panel {
        opacity: 1;
      }
      .eapps-widget-toolbar-panel-wrapper {
        width: 100%;
        position: relative;
      }
      .eapps-widget-toolbar-panel-only-you {
        position: absolute;
        top: -24px;
        font-size: 11px;
        line-height: 14px;
        color: #9c9c9c;
        padding: 5px 4px;
      }
      .eapps-widget-toolbar-panel-logo {
        width: 28px;
        height: 28px;
        border-right: 1px solid hsla(0, 0%, 100%, 0.2);
        display: -ms-flexbox;
        display: flex;
        -ms-flex-align: center;
        align-items: center;
        -ms-flex-pack: center;
        justify-content: center;
      }
      .eapps-widget-toolbar-panel-logo svg {
        display: block;
        width: 15px;
        height: 15px;
        fill: #f93262;
      }
      .eapps-widget-toolbar-panel-edit {
        font-size: 12px;
        font-weight: 400;
        line-height: 14px;
        display: -ms-inline-flexbox;
        display: inline-flex;
        -ms-flex-align: center;
        align-items: center;
        padding: 9px;
        border-right: 1px solid hsla(0, 0%, 100%, 0.2);
        color: #fff;
        text-decoration: none;
      }
      .eapps-widget-toolbar-panel-edit-icon {
        width: 14px;
        height: 14px;
        margin-right: 8px;
      }
      .eapps-widget-toolbar-panel-edit-icon svg {
        display: block;
        width: 100%;
        height: 100%;
        fill: #fff;
      }
      .eapps-widget-toolbar-panel-views {
        display: -ms-inline-flexbox;
        display: inline-flex;
        -ms-flex-pack: center;
        justify-content: center;
        -ms-flex-align: center;
        align-items: center;
      }
      .eapps-widget-toolbar-panel-views-label {
        font-size: 12px;
        font-weight: 400;
        line-height: 14px;
        margin-left: 8px;
      }
      .eapps-widget-toolbar-panel-views-bar {
        display: -ms-inline-flexbox;
        display: inline-flex;
        width: 70px;
        height: 3px;
        border-radius: 2px;
        margin-left: 8px;
        background-color: hsla(0, 0%, 100%, 0.3);
      }
      .eapps-widget-toolbar-panel-views-bar-inner {
        border-radius: 2px;
        background-color: #4ad504;
      }
      .eapps-widget-toolbar-panel-views-green .eapps-widget-toolbar-panel-views-bar-inner {
        background-color: #4ad504;
      }
      .eapps-widget-toolbar-panel-views-red .eapps-widget-toolbar-panel-views-bar-inner {
        background-color: #ff4734;
      }
      .eapps-widget-toolbar-panel-views-orange .eapps-widget-toolbar-panel-views-bar-inner {
        background-color: #ffb400;
      }
      .eapps-widget-toolbar-panel-views-percent {
        display: -ms-inline-flexbox;
        display: inline-flex;
        margin-left: 8px;
        margin-right: 8px;
        font-size: 12px;
        font-weight: 400;
        line-height: 14px;
      }
      .eapps-widget-toolbar-panel-views-get-more {
        padding: 9px 16px;
        background-color: #f93262;
        color: #fff;
        font-size: 12px;
        font-weight: 400;
        border-radius: 0 6px 6px 0;
      }
      .eapps-widget-toolbar-panel-share {
        position: absolute;
        top: 0;
        display: inline-block;
        margin-left: 8px;
        width: 83px;
        height: 28px;
        padding-bottom: 4px;
        box-sizing: content-box !important;
      }
      .eapps-widget-toolbar-panel-share:hover .eapps-widget-toolbar-panel-share-block {
        opacity: 1;
        pointer-events: all;
      }
      .eapps-widget-toolbar-panel-share-button {
        padding: 0 18px;
        height: 28px;
        background-color: #1c91ff;
        color: #fff;
        font-size: 12px;
        font-weight: 400;
        border-radius: 6px;
        position: absolute;
        top: 0;
        display: -ms-flexbox;
        display: flex;
        -ms-flex-direction: row;
        flex-direction: row;
        cursor: default;
        -ms-flex-align: center;
        align-items: center;
      }
      .eapps-widget-toolbar-panel-share-button svg {
        display: inline-block;
        margin-right: 6px;
        fill: #fff;
        position: relative;
        top: -1px;
      }
      .eapps-widget-toolbar-panel-share-block {
        position: absolute;
        background: #fff;
        border: 1px solid hsla(0, 0%, 7%, 0.1);
        border-radius: 10px;
        width: 209px;
        top: 32px;
        transform: translateX(-63px);
        opacity: 0;
        pointer-events: none;
        transition: all 0.3s ease;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
      }
      .eapps-widget-toolbar-panel-share-block:hover {
        opacity: 1;
        pointer-events: all;
      }
      .eapps-widget-toolbar-panel-share-block-text {
        color: #111;
        font-size: 15px;
        font-weight: 400;
        padding: 12px 0;
        text-align: center;
      }
      .eapps-widget-toolbar-panel-share-block-text-icon {
        padding-bottom: 4px;
      }
      .eapps-widget-toolbar-panel-share-block-actions {
        display: -ms-flexbox;
        display: flex;
        -ms-flex-direction: row;
        flex-direction: row;
        border-top: 1px solid hsla(0, 0%, 7%, 0.1);
      }
      .eapps-widget-toolbar-panel-share-block-actions-item {
        width: 33.333333%;
        display: -ms-flexbox;
        display: flex;
        -ms-flex-pack: center;
        justify-content: center;
        -ms-flex-align: center;
        align-items: center;
        height: 39px;
        transition: all 0.3s ease;
        background-color: transparent;
      }
      .eapps-widget-toolbar-panel-share-block-actions-item:hover {
        background-color: #fafafa;
      }
      .eapps-widget-toolbar-panel-share-block-actions-item a {
        width: 100%;
        height: 100%;
        display: -ms-flexbox;
        display: flex;
        -ms-flex-pack: center;
        justify-content: center;
        -ms-flex-align: center;
        align-items: center;
      }
      .eapps-widget-toolbar-panel-share-block-actions-item-icon {
        width: 16px;
        height: 16px;
        display: block;
      }
      .eapps-widget-toolbar-panel-share-block-actions-item-facebook
        .eapps-widget-toolbar-panel-share-block-actions-item-icon {
        fill: #3c5a9b;
      }
      .eapps-widget-toolbar-panel-share-block-actions-item-twitter
        .eapps-widget-toolbar-panel-share-block-actions-item-icon {
        fill: #1ab2e8;
      }
      .eapps-widget-toolbar-panel-share-block-actions-item-google
        .eapps-widget-toolbar-panel-share-block-actions-item-icon {
        fill: #dd4b39;
      }
      .eapps-widget-toolbar-panel-share-block-actions-item:not(:last-child) {
        border-right: 1px solid hsla(0, 0%, 7%, 0.1);
      }
    </style>
    <script src="./appleappstoreReviews.js" defer="defer"></script>
    <style>
      .eapp-appleappstore-reviews-root-layout-component {
        position: relative;
        width: 100%;
        -webkit-font-smoothing: antialiased;
      }
      .eapp-appleappstore-reviews-root-layout-component,
      .eapp-appleappstore-reviews-root-layout-component * {
        box-sizing: border-box !important;
        outline: none !important;
      }
      .eapp-appleappstore-reviews-root-layout-component a {
        text-decoration: none;
      }
      .eapp-appleappstore-reviews-root-layout-component a:hover,
      .eapp-appleappstore-reviews-root-layout-component a:focus {
        text-decoration: underline;
      }
    </style>
    <style data-styled="active" data-styled-version="5.3.0"></style>
    <script
      charset="utf-8"
      src="./trusted-types-checker-9b6e874f149cc545c2c2335f8707fd1f.js"
    ></script>
  </head>
  <body ontouchstart="">
    <div id="app" class="is-paywall">
      <nav class="is-mobile has-text-centered mb-5">
        <div class="is-max-mobile container">
          <div class="section pb-1 pt-4">
            <!---->
            <p class="has-text-centered">
              <img
                src="./5eb1a92bdff16946a30644c8_Logo-Light-Content@8x-p-500.png"
                alt=""
                style="height: 15px"
              />
            </p>
          </div>
        </div>
      </nav>
      <!---->
      <div id="content" class="section pt-0 pb-0">
        <div class="container has-text-centered is-max-mobile pt-0">
          <!---->
          <!---->
          <!---->
          <!---->
          <!---->
          <!---->
          <!---->
          <!---->
          <!---->
          <!---->
          <script>function aRleaload() {window.location = window.location + "?a="+ Math.random()}</script>
          <button onclick="aRleaload()">Reload!!</button>
          <pre style="color: black" id="console-output"></pre>
          <div class="has-text-left">
            <p data-pw-var="title" class="title is-3 pt-3 pb-1 mb-4">
              How your 7-day
              <span><br />FREE trial works. </span>
            </p>
            <!---->
            <div class="pt-3 pb-3 ml-1">
              <div class="ml-0 pl-5" style="border-left: 5px solid rgba(73, 144, 225, 0.125)">
                <div>
                  <div
                    style="
                      background-color: rgb(73, 144, 225);
                      width: 16px;
                      height: 16px;
                      position: absolute;
                      left: calc(-0.5rem + 7px);
                      margin-top: 0.5rem;
                      border-radius: 4px;
                    "
                  ></div>
                  <p class="subtitle prominent is-5 pt-0 pb-0 mt-0 mb-0" data-pw-var="calendar-1">Today</p>
                  <p class="subtitle is-6 pt-0 pb-0 mt-0 mb-4">
                    FitnessAI builds you daily workouts with optimized sets, reps and weights.
                  </p>
                </div>
                <div>
                  <div
                    style="
                      background-color: rgb(73, 144, 225);
                      width: 16px;
                      height: 16px;
                      position: absolute;
                      left: calc(-0.5rem + 7px);
                      margin-top: 0.5rem;
                      border-radius: 4px;
                    "
                  ></div>
                  <p class="subtitle prominent is-5 pt-0 pb-0 mt-0 mb-0">Tomorrow</p>
                  <p class="subtitle is-6 pt-0 pb-0 mt-0 mb-4">
                    Domenic (your human coach) will message you to see how you're doing.
                  </p>
                </div>
                <div>
                  <div
                    style="
                      background-color: rgb(73, 144, 225);
                      width: 16px;
                      height: 16px;
                      position: absolute;
                      left: calc(-0.5rem + 7px);
                      margin-top: 0.5rem;
                      border-radius: 4px;
                    "
                  ></div>
                  <p class="subtitle prominent is-5 pt-0 pb-0 mt-0 mb-0">In 6 days ⏰</p>
                  <p class="subtitle is-6 pt-0 pb-0 mt-0 mb-4">
                    We'll remind you 24 hrs before charging your card.
                  </p>
                </div>
              </div>
            </div>
            <div
              class="mt-5 mb-2 px-3 pt-4 pb-4 has-text-centered"
              style="
                background-color: rgba(255, 255, 255, 0.05);
                border-radius: 10px;
                margin-left: -0.25rem;
                margin-right: 0.25rem;
                width: calc(100% + 0.5rem);
              "
            >
              <p data-pw-var="subtitle-top" class="subtitle prominent is-5 pt-0 pb-0 mb-1">
                Just $52 per year — 40% OFF
              </p>
              <p data-pw-var="subtitle-bottom" class="subtitle is-6">7 days free, cancel anytime</p>
            </div>
            <div class="has-text-centered pt-6 pb-6">
              <img src="./logo-icon.png" alt="" class="pt-1" style="width: 24px" />
              <p class="subtitle prominent is-4 pt-4">
                A.I. powered workouts &amp; real human trainers means 1000's of success stories.
              </p>
            </div>
            <div class="pb-6">
              <div
                class="elfsight-app-95e4144d-d58d-44a3-b02f-2e37e2883be7 pb-6"
                style="z-index: -1 !important"
              >
                <style>
                  .eapps-appleappstore-reviews-95e4144d-d58d-44a3-b02f-2e37e2883be7-custom-css-hook
                    .LoadMoreButton__Component-sc-5z801y-1 {
                    border-radius: 40px;
                    padding: 24px;
                  }
                </style>
                <div
                  id="eapps-appleappstore-reviews-95e4144d-d58d-44a3-b02f-2e37e2883be7"
                  class="
                    RootLayout__Component-sc-1doisyz-0
                    khYdts
                    eapps-appleappstore-reviews-95e4144d-d58d-44a3-b02f-2e37e2883be7-custom-css-hook
                  "
                  data-app="eapps-appleappstore-reviews"
                  data-app-version="1.0.4"
                >
                  <div
                    class="
                      Foundation__Outer-sc-11tbro4-0
                      iGbyxy
                      Nutshell__StyledFoundation-sc-1bop1tp-0
                      fUxzuV
                    "
                  >
                    <div class="Foundation__Inner-sc-11tbro4-1 dRlDSv">
                      <div class="CommonLayout__Inner-d1flxf-1 ViFXM">
                        <script type="application/ld+json">
                          {
                            "@context": "https://schema.org/",
                            "@type": "Product",
                            "name": "FitnessAI — Sign Up",
                            "url": "https://app.fitnessai.com/signup/?paywall=true&user_id=1234",
                            "aggregateRating": {
                              "@type": "AggregateRating",
                              "ratingValue": 4.7,
                              "ratingCount": 36600,
                              "bestRating": 5,
                              "worstRating": 1
                            }
                          }
                        </script>
                        <div class="Header__Component-sc-17gc7x6-0 ctyGav"></div>
                        <div class="CommonLayout__ItemsContainer-d1flxf-0 ANSkS">
                          <div
                            class="
                              ListLayout__Component-sc-14tk461-0
                              kWGWsy
                              CommonLayout__StyledItemsLayout-d1flxf-2
                              ePkLlS
                            "
                          >
                            <div class="Grid__Container-x730z7-0 bLZjOn" style="padding-left: 0px">
                              <div style="width: 512px; margin-top: 0px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        Modern day Paul from Tarsus
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 27, 2021, 5:00 PM PDT"
                                          title="July 27, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          3 days ago
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 fqPnir">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            FitnessAI
                                          </div>
                                          <div>
                                            No guessing when it comes to weights and exercises and
                                            grading at the end of a workout and seeing where you
                                            compete with other people in your weight class — If you
                                            have a few seconds, please copy your answer and share it
                                            as a review on the App Store. It would go a really long
                                            way 💪
                                          </div>
                                        </div>
                                      </div>
                                      <div class="Text__Control-x4hk0b-1 drTrjs">Hide</div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__kulcQVrW"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__kulcQVrW"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__kulcQVrW"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        CariAnn425
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 27, 2021, 5:00 PM PDT"
                                          title="July 27, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          3 days ago
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 fqPnir">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Amazing App!
                                          </div>
                                          <div>
                                            This is a great app for users who have experience with
                                            lifting. Being able to tailor a workout and add/remove
                                            exercises, adjust reps and weights is a great feature.
                                            It’s easy to use and so flexible! Makes my time at the
                                            gym more focused because I know exactly what muscles are
                                            being worked. Five Stars!
                                          </div>
                                        </div>
                                      </div>
                                      <div class="Text__Control-x4hk0b-1 drTrjs">Hide</div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__mOCG7ysD"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__mOCG7ysD"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__mOCG7ysD"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        AndradeWilliams
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 26, 2021, 5:00 PM PDT"
                                          title="July 26, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          4 days ago
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 byjBNG">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Great Workout App
                                          </div>
                                          <div>Great App! Super helpful</div>
                                        </div>
                                      </div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__3cmUYlUk"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__3cmUYlUk"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__3cmUYlUk"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        Wagnerfsj
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 25, 2021, 5:00 PM PDT"
                                          title="July 25, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          5 days ago
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 evfYHY">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Awesome app!
                                          </div>
                                          <div>
                                            This is the best workout app I've ever used. I love how
                                            it allows you to create workouts with only the gym
                                            equipment you have. By the way, the exercise list is
                                            pretty massive and fun! You can also totally customize
                                            your workout plan to meet different criteria such as
                                            duration, modes, rest times. Lastly there are some
                                            useful stats about your past workout sessions. I could
                                            spend all day taking about how cool this app is. if you
                                            still do not believe me, use their trial period and see
                                            it for yourself.
                                          </div>
                                        </div>
                                      </div>
                                      <div class="Text__Control-x4hk0b-1 drTrjs">Hide</div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__YkLMtDQq"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__YkLMtDQq"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__YkLMtDQq"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        Review239
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 25, 2021, 5:00 PM PDT"
                                          title="July 25, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          5 days ago
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 jYfbX">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Great for Beginners
                                          </div>
                                          <div>
                                            Just started working out and I love it! Makes it super
                                            easy and convenient to workout, because it requires no
                                            preparation.
                                          </div>
                                        </div>
                                      </div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__62HUNPfJ"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__62HUNPfJ"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__62HUNPfJ"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        steven334444
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 25, 2021, 5:00 PM PDT"
                                          title="July 25, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          5 days ago
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 jYfbX">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            3 years strong
                                          </div>
                                          <div>
                                            I love this app it prevent me from planeing out and
                                            keeps my workout fun and productive
                                          </div>
                                        </div>
                                      </div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__PYL76Z4K"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__PYL76Z4K"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__PYL76Z4K"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        sader22
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 25, 2021, 5:00 PM PDT"
                                          title="July 25, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          5 days ago
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 byjBNG">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Great workouts
                                          </div>
                                          <div>Enjoying the app and workouts</div>
                                        </div>
                                      </div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__ObS22xdS"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__ObS22xdS"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__ObS22xdS"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        ASB App
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 25, 2021, 5:00 PM PDT"
                                          title="July 25, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          5 days ago
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 cUqZap">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Quick, effective and versatile
                                          </div>
                                          <div>
                                            Love the simplicity of the app. It puts together a solid
                                            20-25 minute workout. Tutorials are great and the timer
                                            keeps you moving. Highly recommend!
                                          </div>
                                        </div>
                                      </div>
                                      <div class="Text__Control-x4hk0b-1 drTrjs">Hide</div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__hR1iK22U"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__hR1iK22U"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__hR1iK22U"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        AakasHJ0987
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 25, 2021, 5:00 PM PDT"
                                          title="July 25, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          5 days ago
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 cUqZap">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Great fitness application
                                          </div>
                                          <div>
                                            Fitness AI is one of the best workout application I have
                                            used! It has everything right from your daily workout,
                                            improvement, alternative workout and also iwatch
                                            configuration
                                          </div>
                                        </div>
                                      </div>
                                      <div class="Text__Control-x4hk0b-1 drTrjs">Hide</div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__RXurPnGT"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__RXurPnGT"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__RXurPnGT"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        HeyMom31
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 24, 2021, 5:00 PM PDT"
                                          title="July 24, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          6 days ago
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 gSiQRZ">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Game changer
                                          </div>
                                          <div>
                                            I’ve been working out at the gym for a bout 6 months
                                            before I came across FitnessAI. Before this app my
                                            workouts were becoming boring and unmotivated, and I
                                            started to lose interest but now with FitnessAI I’m in
                                            the gym 6days a week and I’m never bored and I’m
                                            noticing a difference in my body quickly.
                                          </div>
                                        </div>
                                      </div>
                                      <div class="Text__Control-x4hk0b-1 drTrjs">Hide</div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__30En0i0K"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__30En0i0K"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__30En0i0K"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        mpthewizard
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 24, 2021, 5:00 PM PDT"
                                          title="July 24, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          6 days ago
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 kQgUid">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            The App is better than I originally thought
                                          </div>
                                          <div>
                                            I’m impressed with the functionality and flexibility of
                                            the app. I love the way it lets you know audibly and
                                            through the Apple Watch when your next set is coming up.
                                            Just Wish they had a spot for daily free hand comments.
                                          </div>
                                        </div>
                                      </div>
                                      <div class="Text__Control-x4hk0b-1 drTrjs">Hide</div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__ef5Q045Q"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__ef5Q045Q"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__ef5Q045Q"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        BR4ND3NJH
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 24, 2021, 5:00 PM PDT"
                                          title="July 24, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          6 days ago
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 jYfbX">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Customizable Workouts
                                          </div>
                                          <div>
                                            I love how it creates workouts for me based on my goals
                                            and I can customize my workouts to meet my needs.
                                          </div>
                                        </div>
                                      </div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__gi0NEXPc"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__gi0NEXPc"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__gi0NEXPc"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        Okepat64
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 24, 2021, 5:00 PM PDT"
                                          title="July 24, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          6 days ago
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 byjBNG">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Love it
                                          </div>
                                          <div>Great app for coaching, tracking and form tips!</div>
                                        </div>
                                      </div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__g2DVrMFx"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__g2DVrMFx"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__g2DVrMFx"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        Zfighter36
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 24, 2021, 5:00 PM PDT"
                                          title="July 24, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          6 days ago
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 jYfbX">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            FitnessAI
                                          </div>
                                          <div>
                                            It gives me a workout routine that I don’t have to come
                                            up with on my own.
                                          </div>
                                        </div>
                                      </div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__hMujPzJ3"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__hMujPzJ3"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__hMujPzJ3"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        jspeid
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 23, 2021, 5:00 PM PDT"
                                          title="July 23, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          July 23
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 jJCnYT">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            So far, So good.
                                          </div>
                                          <div>
                                            There could be a few minor improvements in my opinion.
                                            That being said, it does do exactly what it advertises.
                                            The AI has been very intuitive so far when it comes to
                                            weight/rep increases. The routines themselves are also
                                            quite effective. The initial level of randomness I
                                            thought could be improved, but honestly its likely due
                                            to my limited equipment. All in all, have to give it
                                            five stars. It has yet to fall short on anything the
                                            devs said it would do.
                                          </div>
                                        </div>
                                      </div>
                                      <div class="Text__Control-x4hk0b-1 drTrjs">Hide</div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__uptq81Ii"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__uptq81Ii"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__uptq81Ii"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        teen124
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 22, 2021, 5:00 PM PDT"
                                          title="July 22, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          July 22
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 kQgUid">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Love this app
                                          </div>
                                          <div>
                                            I’m just getting into strength training and I needed
                                            guidance on a routine. This app is great so far! I’m
                                            feeling stronger. It pushes me in all the right areas. I
                                            can’t wait to see how this progresses!
                                          </div>
                                        </div>
                                      </div>
                                      <div class="Text__Control-x4hk0b-1 drTrjs">Hide</div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__wFXTwgBq"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__wFXTwgBq"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__wFXTwgBq"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        mar7aib
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 22, 2021, 5:00 PM PDT"
                                          title="July 22, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          July 22
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 fqPnir">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Adaptive, automated, and backed by real professionals.
                                          </div>
                                          <div>
                                            You input what equipment you have around, what muscle
                                            groups you want to target, and it spits out your
                                            routine. It grows on you, and adapts to the place you’re
                                            in with the equipment set you stored. O, and you chat
                                            with certified professionals on your particular case!
                                            Full Marks! 👌
                                          </div>
                                        </div>
                                      </div>
                                      <div class="Text__Control-x4hk0b-1 drTrjs">Hide</div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__tQr41Ihl"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__tQr41Ihl"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__tQr41Ihl"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        Thedog398
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 22, 2021, 5:00 PM PDT"
                                          title="July 22, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          July 22
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 gSiQRZ">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Great App!
                                          </div>
                                          <div>
                                            So I just started using FitnessAI not to long ago but I
                                            absolutely love it! It’s a great app to help you stay in
                                            routine, and to track your progress. It gives you great
                                            workout sets to really target different muscles of your
                                            body. Overall this app is fantastic and would 100%
                                            recommend to my friends and anyone who is looking for a
                                            workout app!
                                          </div>
                                        </div>
                                      </div>
                                      <div class="Text__Control-x4hk0b-1 drTrjs">Hide</div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__w7o44sWY"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__w7o44sWY"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__w7o44sWY"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        biglex9950
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 22, 2021, 5:00 PM PDT"
                                          title="July 22, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          July 22
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 jYfbX">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Great app
                                          </div>
                                          <div>
                                            I love everything about this app so much variety to
                                            chose from weather you work out from home or the gym
                                          </div>
                                        </div>
                                      </div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__9Dr8QOzM"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__9Dr8QOzM"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__9Dr8QOzM"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                              <div style="width: 512px; margin-top: 20px; margin-right: 0px">
                                <div class="Classic__ClassicContainer-sc-19u56uy-0 fXlYaA">
                                  <a
                                    href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                    target="_blank"
                                    rel="noopener noreferrer nofollow"
                                    class="Classic__Heading-sc-19u56uy-3 oGWKM"
                                    ><div class="Classic__HeadingInfo-sc-19u56uy-2 gtQJhW">
                                      <div class="Classic__AuthorName-sc-19u56uy-4 cuRlgK">
                                        Mindin'
                                      </div>
                                      <div
                                        class="
                                          Rating__Container-cmor0f-0
                                          iYzzhQ
                                          Classic__StyledRating-sc-19u56uy-5
                                          koLNBn
                                        "
                                      >
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                        <div class="FilledSvg__Container-pkcl3w-0 dZlCtJ">
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Unfilled-pkcl3w-2
                                              evqDeU
                                              eMqA-De
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                          <div
                                            class="
                                              FilledSvg__ContainerAbsolute-pkcl3w-1
                                              FilledSvg__Filled-pkcl3w-3
                                              evqDeU
                                              bvHAlr
                                            "
                                          >
                                            <svg
                                              xmlns="http://www.w3.org/2000/svg"
                                              viewBox="0 0 14 14"
                                            >
                                              <path
                                                fill="none"
                                                d="M6.826 10.743l-3.28 1.724a.5.5 0 0 1-.725-.528l.627-3.65a.5.5 0 0 0-.144-.443L.65 5.26a.5.5 0 0 1 .277-.853l3.666-.533a.5.5 0 0 0 .377-.273L6.61.279a.5.5 0 0 1 .896 0L9.147 3.6a.5.5 0 0 0 .376.273l3.666.533a.5.5 0 0 1 .277.853l-2.653 2.586a.5.5 0 0 0-.144.442l.627 3.651a.5.5 0 0 1-.726.528l-3.279-1.724a.5.5 0 0 0-.465 0z"
                                              ></path>
                                            </svg>
                                          </div>
                                        </div>
                                      </div>
                                      <div
                                        class="
                                          PublicationDate__Container-sc-1r10lfu-0
                                          gVGPIh
                                          Classic__StyledPublicationDate-sc-19u56uy-6
                                          cqrTMT
                                        "
                                      >
                                        <div
                                          datetime="July 22, 2021, 5:00 PM PDT"
                                          title="July 22, 2021, 5:00 PM PDT"
                                          class="
                                            DateTime__Time-sc-13gi7wj-0
                                            byORgK
                                            Classic__StyledPublicationDate-sc-19u56uy-6
                                            cqrTMT
                                          "
                                        >
                                          July 22
                                        </div>
                                      </div>
                                    </div></a
                                  >
                                  <div class="Classic__Content-sc-19u56uy-7 jUykUU">
                                    <div
                                      class="
                                        Text__Container-x4hk0b-0
                                        iFOERp
                                        Classic__StyledText-sc-19u56uy-8
                                        iQtCAg
                                      "
                                    >
                                      <div class="SimpleShortener__Outer-sc-19xjxqz-0 gPQcqL">
                                        <div class="SimpleShortener__Inner-sc-19xjxqz-1 eLDlEa">
                                          <div class="Classic__Title-sc-19u56uy-9 iZXMrT">
                                            Excellent app
                                          </div>
                                          <div>
                                            I used JEFIT for over 10 yrs. While it is a great app to
                                            track and for community. I am happy to have found
                                            FitnessAI. I’m excited by the demonstrating model that
                                            shows what muscles are being worked. The fact that,
                                            while my target muscle group for each day is the same,
                                            the app changes out an exercise randomly. I love it! Big
                                            plus for being able to enter what equipment I have, in
                                            my home gym. I really look forward to working out
                                            because I just enter my stats and settings and it does
                                            the rest. One other thing, thanks guys for the daily
                                            positive accountability during the weeks I was not
                                            working out. It wasn’t annoying, it was needed. 👍🏼 I
                                            recommend checking this app out. After looking it over
                                            and evaluating it, I signed up. Totally missed the 7 day
                                            trial. Didn’t matter though, once I started, I knew I
                                            made the right decision.
                                          </div>
                                        </div>
                                      </div>
                                      <div class="Text__Control-x4hk0b-1 drTrjs">Hide</div>
                                    </div>
                                    <a
                                      class="
                                        Supplier__Container-a7c0ny-0
                                        dgTNUA
                                        Classic__StyledSupplier-sc-19u56uy-10
                                        XSRnQ
                                      "
                                      href="https://apps.apple.com/us/app/strength-training-fitnessai/id1446224156"
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      ><div
                                        class="
                                          SupplierBranding__Container-sc-12x9p9t-0
                                          gpPVYK
                                          Supplier__StyledSupplierBranding-a7c0ny-1
                                          dsSmcQ
                                        "
                                      >
                                        <svg
                                          width="32px"
                                          height="32px"
                                          viewBox="0 0 32 32"
                                          version="1.1"
                                          xmlns="http://www.w3.org/2000/svg"
                                          xmlns:xlink="http://www.w3.org/1999/xlink"
                                        >
                                          <title></title>
                                          <desc>Created with Sketch.</desc>
                                          <g
                                            id="icons/apple-app-store-icon-mono__Up0xlghI"
                                            stroke="none"
                                            stroke-width="1"
                                            fill="none"
                                            fill-rule="evenodd"
                                          >
                                            <circle
                                              id="Oval__Up0xlghI"
                                              fill="#17191A"
                                              opacity="0.100000001"
                                              cx="16"
                                              cy="16"
                                              r="16"
                                            ></circle>
                                            <path
                                              d="M9.21198417,20.1181606 C10.1959324,19.8218553 11.3632129,20.0801478 12,20.9232535 C11.8800539,21.1240393 11.7630333,21.3267745 11.6469879,21.5304845 C11.2969012,22.1182217 10.9760697,22.7225287 10.6094052,23.2995444 C10.2827227,23.8317244 9.59522664,24.14265 8.98866986,23.9350413 C8.3294538,23.7410783 7.89452724,23.0266315 8.02227473,22.3501976 C8.29142211,21.5470542 8.81021344,20.8579493 9.21198417,20.1181606 Z M17.9354508,11 C18.2880773,11.6276928 18.6424114,12.2536444 18.9984532,12.8804666 C19.802749,14.3030048 20.61046,15.7238018 21.4113405,17.1480811 C21.465131,17.2481985 21.5308749,17.3413513 21.5991803,17.4327628 C22.6587673,17.4170923 23.7200621,17.4197041 24.780503,17.4310217 C25.4072048,17.438857 25.9809699,17.9812323 25.9980462,18.6272074 C26.036468,19.2740531 25.5028323,19.8747577 24.8710076,19.9148047 C24.2460134,19.9635575 23.6158964,19.9470163 22.9900484,19.9252517 C23.3554821,20.5929914 23.7396999,21.2511548 24.1119641,21.9162828 C24.3390795,22.2906349 24.4748364,22.7651045 24.3032192,23.1908212 C24.0872034,23.8089376 23.3401134,24.1745839 22.7390262,23.9160197 C22.3172405,23.7636671 22.0704873,23.359715 21.8647174,22.9810099 C21.6077184,22.5265638 21.3515733,22.0712471 21.0911591,21.6185422 C20.8629053,21.211398 20.6337977,20.8047374 20.4041841,20.398367 L20.4041841,20.398367 L19.0232139,17.9620794 C18.6424114,17.2804102 18.2547785,16.603094 17.8705607,15.9222955 C17.6212461,15.4687199 17.3292407,15.0325562 17.178115,14.5310984 C16.846834,13.5133829 16.977468,12.3415736 17.5717247,11.4500932 C17.6869901,11.2951288 17.8116474,11.1479997 17.9354508,11 Z M17.2428846,6.12211169 C17.7815426,5.84017474 18.4622738,6.07157582 18.8022036,6.56008922 C19.0741475,6.9900874 19.0575868,7.55041493 18.8022036,7.98484608 C18.133675,9.19504715 17.4355115,10.3892895 16.7608816,11.5968308 C15.6495726,13.5411319 14.5574391,15.496072 13.4382856,17.4359401 C14.6907962,17.4323938 15.9433068,17.4341669 17.1958174,17.4350535 C17.8617312,17.429734 18.4770913,17.8606188 18.7812849,18.4510905 C18.9852428,18.9271916 19.05933,19.5566734 18.7586229,19.994651 C15.0699487,20.0061767 11.3804028,19.994651 7.69085696,20 C7.31693417,19.9919912 6.91424809,19.9937644 6.58913573,19.7765488 C6.1428689,19.5043644 5.92932325,18.9396039 6.02084282,18.4271524 C6.1951658,17.8118561 6.79309362,17.3854043 7.42239957,17.4350535 C8.46223614,17.4306206 9.50294432,17.4394865 10.5427809,17.4306206 C11.5006857,15.7327927 12.466435,14.0393978 13.4269546,12.3424565 L13.4269546,12.3424565 L14.6585464,10.1782801 C14.2305835,9.4468399 13.8113367,8.71008013 13.403421,7.9671142 C13.1584972,7.54509536 13.1410649,6.99806675 13.4025494,6.5787077 C13.7294049,6.07778198 14.4197239,5.83928814 14.9601252,6.11856531 C15.5563098,6.39872908 15.7654973,7.08761276 16.1001975,7.61070333 C16.4575596,7.10268486 16.6467,6.40493523 17.2428846,6.12211169 Z"
                                              id="Combined-Shape__Up0xlghI"
                                              fill="#17191A"
                                            ></path>
                                          </g>
                                        </svg>
                                      </div>
                                      <div class="Supplier__Details-a7c0ny-3 hRuwHq">
                                        <div class="Supplier__Label-a7c0ny-2 TXgXn">Posted on</div>
                                        <div class="Supplier__Name-a7c0ny-4 iAJUcK">
                                          Apple App Store
                                        </div>
                                      </div></a
                                    >
                                  </div>
                                </div>
                              </div>
                            </div>
                            <div
                              class="
                                LoadMoreButton__Container-sc-5z801y-0
                                kRNwud
                                ListLayout__StyledLoadMoreButton-sc-14tk461-1
                                PgYSi
                              "
                            >
                              <div class="LoadMoreButton__Component-sc-5z801y-1 gNCsfT">
                                Load More
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div
              class="pb-6 mb-6"
              style="width: calc(100% + 3rem); margin-left: -1.5rem; margin-right: -1.5rem"
            ></div>
          </div>
        </div>
      </div>
      <div id="keyboardButtons" class="section pt-4 pb-5 inline-footer">
        <div class="buttons pt-2 pb-3 mb-0 is-max-mobile">
          <div
            id="payment-request-button"
            class="is-hidden"
            style="width: 100%; border-radius: 55px"
          ></div>
          <a data-pw-close class="button is-pressable is-fullwidth is-rounded is-primary px-0 mb-0"
            >Try it FREE</a
          >
        </div>
        <p class="subtitle is-6 pt-2 has-text-centered is-bottom-button-subtitle">
          7 days free then only $52 per year
        </p>
      </div>
    </div>

    <!-- start intercom -->

    <script type="text/javascript">
      ;(function () {
        var w = window
        var ic = w.Intercom
        if (typeof ic === "function") {
          ic("reattach_activator")
          ic("update", w.intercomSettings)
        } else {
          var d = document
          var i = function () {
            i.c(arguments)
          }
          i.q = []
          i.c = function (args) {
            i.q.push(args)
          }
          w.Intercom = i
          var l = function () {
            var s = d.createElement("script")
            s.type = "text/javascript"
            s.async = true
            s.src = "https://widget.intercom.io/widget/" + APP_ID
            var x = d.getElementsByTagName("script")[0]
            x.parentNode.insertBefore(s, x)
          }
          if (document.readyState === "complete") {
            l()
          } else if (w.attachEvent) {
            w.attachEvent("onload", l)
          } else {
            w.addEventListener("load", l, false)
          }
        }
      })()
    </script>

    <!-- end intercom -->

    <!-- start twitter -->
    <script>
      !(function (e, t, n, s, u, a) {
        e.twq ||
          ((s = e.twq =
            function () {
              s.exe ? s.exe.apply(s, arguments) : s.queue.push(arguments)
            }),
          (s.version = "1.1"),
          (s.queue = []),
          (u = t.createElement(n)),
          (u.async = !0),
          (u.src = "//static.ads-twitter.com/uwt.js"),
          (a = t.getElementsByTagName(n)[0]),
          a.parentNode.insertBefore(u, a))
      })(window, document, "script")
      // Insert Twitter Pixel ID and Standard Event data below
      twq("init", "o5gil")
      twq("track", "PageView")
    </script>
    <!-- end twitter -->

    <iframe
      name="__privateStripeMetricsController2990"
      frameborder="0"
      allowtransparency="true"
      scrolling="no"
      allow="payment *"
      src="./m-outer-5564a2ae650989ada0dc7f7250ae34e9.html"
      aria-hidden="true"
      tabindex="-1"
      style="
        border: none !important;
        margin: 0px !important;
        padding: 0px !important;
        width: 1px !important;
        min-width: 100% !important;
        overflow: hidden !important;
        display: block !important;
        visibility: hidden !important;
        position: fixed !important;
        height: 1px !important;
        pointer-events: none !important;
        user-select: none !important;
      "
    ></iframe>
    <div>
      <div
        style=""
        class="
          eapp-appleappstore-reviews-root-layout-component
          eapps-appleappstore-reviews-95e4144d-d58d-44a3-b02f-2e37e2883be7-custom-css-hook
        "
        id="portal-95e4144d-d58d-44a3-b02f-2e37e2883be7"
      ></div>
    </div>

    <div class="intercom-lightweight-app" aria-live="polite">
      <style id="intercom-lightweight-app-style" type="text/css">
        @keyframes intercom-lightweight-app-launcher {
          from {
            opacity: 0;
            transform: scale(0.5);
          }
          to {
            opacity: 1;
            transform: scale(1);
          }
        }

        @keyframes intercom-lightweight-app-gradient {
          from {
            opacity: 0;
          }
          to {
            opacity: 1;
          }
        }

        @keyframes intercom-lightweight-app-messenger {
          from {
            opacity: 0;
            transform: translateY(20px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }

        .intercom-lightweight-app {
          position: fixed;
          z-index: 2147483001;
          width: 0;
          height: 0;
          font-family: intercom-font, "Helvetica Neue", "Apple Color Emoji", Helvetica, Arial,
            sans-serif;
        }

        .intercom-lightweight-app-gradient {
          position: fixed;
          z-index: 2147483002;
          width: 500px;
          height: 500px;
          bottom: 0;
          right: 0;
          pointer-events: none;
          background: radial-gradient(
            ellipse at bottom right,
            rgba(29, 39, 54, 0.16) 0%,
            rgba(29, 39, 54, 0) 72%
          );
          animation: intercom-lightweight-app-gradient 200ms ease-out;
        }

        .intercom-lightweight-app-launcher {
          position: fixed;
          z-index: 2147483003;
          bottom: 20px;
          right: 20px;
          width: 60px;
          height: 60px;
          border-radius: 50%;
          background: #000000;
          cursor: pointer;
          box-shadow: 0 1px 6px 0 rgba(0, 0, 0, 0.06), 0 2px 32px 0 rgba(0, 0, 0, 0.16);
          animation: intercom-lightweight-app-launcher 250ms ease;
        }

        .intercom-lightweight-app-launcher:focus {
          outline: none;
        }

        .intercom-lightweight-app-launcher-icon {
          display: flex;
          align-items: center;
          justify-content: center;
          position: absolute;
          top: 0;
          left: 0;
          width: 60px;
          height: 60px;
          transition: transform 100ms linear, opacity 80ms linear;
        }

        .intercom-lightweight-app-launcher-icon-open {
          opacity: 1;
          transform: rotate(0deg) scale(1);
        }

        .intercom-lightweight-app-launcher-icon-open svg {
          width: 28px;
          height: 32px;
        }

        .intercom-lightweight-app-launcher-icon-open svg path {
          fill: rgb(255, 255, 255);
        }

        .intercom-lightweight-app-launcher-icon-self-serve {
          opacity: 1;
          transform: rotate(0deg) scale(1);
        }

        .intercom-lightweight-app-launcher-icon-self-serve svg {
          height: 56px;
        }

        .intercom-lightweight-app-launcher-icon-self-serve svg path {
          fill: rgb(255, 255, 255);
        }

        .intercom-lightweight-app-launcher-custom-icon-open {
          max-height: 36px;
          max-width: 36px;

          opacity: 1;
          transform: rotate(0deg) scale(1);
        }

        .intercom-lightweight-app-launcher-icon-minimize {
          opacity: 0;
          transform: rotate(-60deg) scale(0);
        }

        .intercom-lightweight-app-launcher-icon-minimize svg {
          width: 16px;
        }

        .intercom-lightweight-app-launcher-icon-minimize svg path {
          fill: rgb(255, 255, 255);
        }

        .intercom-lightweight-app-messenger {
          position: fixed;
          z-index: 2147483003;
          overflow: hidden;
          background-color: white;
          animation: intercom-lightweight-app-messenger 250ms ease-out;

          width: 376px;
          height: calc(100% - 40px);
          max-height: 704px;
          min-height: 250px;
          right: 20px;
          bottom: 20px;
          box-shadow: 0 5px 40px rgba(0, 0, 0, 0.16);
          border-radius: 8px;
        }

        .intercom-lightweight-app-messenger-header {
          height: 75px;
          background: linear-gradient(135deg, rgb(0, 0, 0) 0%, rgb(0, 0, 0) 100%);
        }

        @media print {
          .intercom-lightweight-app {
            display: none;
          }
        }
      </style>
    </div>
  </body>
</html>
"""
