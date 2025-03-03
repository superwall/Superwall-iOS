//
//  SuperwallBasicApp.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI
import Combine
import SuperwallKit

@main
struct SuperwallBasicApp: App {
  @State private var isLoggedIn = false
  private var isPreviouslyLoggedIn = CurrentValueSubject<Bool, Never>(false)

  init() {
    #warning("For your own app you will need to use your own API key, available from the Superwall Dashboard")

    let apiKey = "pk_b3f3f3098ba5a84843ec9d3bf7e00578aeea8bc6c74a68fa"
    Superwall.configure(apiKey: apiKey)

//    will_end_in_days  -87  Int64
//    user_language_ios  en  String
//    userId  171165864  Int64
//    subscription_status  never_subscribed  String
//    sessions  14  Int64
//    seed  17  Int64
//    region  LT  String
//    promotional_offer_available  false  Bool
//    paid  false  Bool
//    os  iOS Version 18.2 (Build 22C150)  String
//    language  en-US  String
//    intro_offer_available  true  Bool
//    installationHash  3bb64f67d1de5838246509b65cd3f2185213445fc95b36f31a0e28ebe8b4d968  String
//    first_name  User 171165864  String
//    email  alexkartsev1994+1@gmail.com  String
//    device  arm64  String
//    country  ES  String
//    builtInDatabaseVersion  1737017773  Int64
//    applicationVersion  4.56.0  String
//    applicationInstalledAt  2025-03-03T15:30:55.633Z  String
//    application  com.planner5d.Planner-5D  String
//    apple_search_ads_org_id  1234567890  Int64
//    apple_search_ads_keyword_id  12323222  Int64
//    apple_search_ads_country_or_region  US  String
//    apple_search_ads_conversion_type  Download  String
//    apple_search_ads_click_date  2025-02-28T14:23Z  String
//    apple_search_ads_campaign_id  1234567890  Int64
//    apple_search_ads_attribution  true  Bool
//    apple_search_ads_ad_id  1234567890  Int64
//    apple_search_ads_ad_group_id  1234567890  Int64
//    appUserId  171165864  String
//    aliasId  $SuperwallAlias:9DDC5DDD-AFFC-49F3-9B84-3B2F11B33D9C  String
//    activeDatabaseVersion0  1737017773  Int64
//    activeDatabaseVersion  1737017773  Int64
//    $application_installed_at  2025-03-03T15:30:55.633Z  String
//    $app_session_id  931A0FB3-9C99-46ED-80F4-F393C300AE41  String

    isPreviouslyLoggedIn.send(Superwall.shared.isLoggedIn)
  }

  var body: some Scene {
    WindowGroup {
      WelcomeView(isLoggedIn: $isLoggedIn)
        .font(.rubik(.four))
        .onOpenURL { url in
          Superwall.shared.handleDeepLink(url)
        }
        .onReceive(isPreviouslyLoggedIn) { isLoggedIn in
          self.isLoggedIn = isLoggedIn
        }
    }
  }
}
