import Foundation

/// Pays the first-use decoding cost while a cache-miss config request is in flight.
/// The synthetic model is discarded; it is never applied, persisted, or presented.
final class ConfigDecodingPrewarmer {
  static let shared = ConfigDecodingPrewarmer()

  private let lock = NSLock()
  private var hasScheduled = false
  private let schedule: (@escaping () -> Void) -> Void
  private let decode: () throws -> Void

  init(
    schedule: @escaping (@escaping () -> Void) -> Void = { work in
      DispatchQueue.global(qos: .utility).async(execute: work)
    },
    decode: @escaping () throws -> Void = {
      _ = try JSONDecoder.fromSnakeCase.decode(Config.self, from: Data(ConfigDecodingPrewarmer.fixture.utf8))
    }
  ) {
    self.schedule = schedule
    self.decode = decode
  }

  /// Called after the network task resumes. Retries and concurrent fetches cannot
  /// schedule another warmup, and response handling never waits for this work.
  func start() {
    lock.lock()
    guard !hasScheduled else {
      lock.unlock()
      return
    }
    hasScheduled = true
    lock.unlock()

    schedule { [decode] in
      autoreleasepool {
        // A future schema change must not turn this optimization into a failure
        // of the real request. The fixture's type coverage is tested separately.
        try? decode()
      }
    }
  }
}

extension ConfigDecodingPrewarmer {
  /// Synthetic identifiers and reserved `.invalid` URLs only. No resources or
  /// customer data are needed to exercise the representative decoding paths.
  static let fixture = #"""
  {
    "build_id": "superwall-config-prewarm",
    "trigger_options": [
      {
        "trigger_version": "V2",
        "event_name": "configDecoder_prewarm",
        "rules": [
          {
            "experiment_group_id": "prewarm-group",
            "experiment_id": "prewarm-experiment",
            "expression": null,
            "expression_cel": "true",
            "computed_properties": [],
            "preload": {
              "behavior": "IF_TRUE"
            },
            "referenced_properties": [],
            "expression_js": null,
            "variants": [
              {
                "percentage": 100,
                "variant_type": "TREATMENT",
                "variant_id": "prewarm-variant",
                "paywall_identifier": "superwall-config-prewarm"
              }
            ]
          }
        ]
      }
    ],
    "paywall_responses": [
      {
        "id": "prewarm-paywall",
        "build_id": "superwall-config-prewarm",
        "cache_key": "superwall-config-prewarm",
        "url": "https://config-prewarm.invalid/paywall",
        "url_config": {
          "endpoints": [
            {
              "url": "https://config-prewarm.invalid/paywall",
              "percentage": 100,
              "timeout_ms": 1000
            }
          ],
          "max_attempts": 1
        },
        "name": "Config decoder warmup",
        "identifier": "superwall-config-prewarm",
        "paywalljs_event": "",
        "feature_gating": "NON_GATED",
        "on_device_cache": "DISABLED",
        "products_v2": [
          {
            "sw_composite_product_id": "superwall.prewarm.primary",
            "reference_name": "primary",
            "store_product": {
              "store": "APP_STORE",
              "product_identifier": "superwall.prewarm.primary"
            },
            "entitlements": [
              {
                "identifier": "prewarm",
                "type": "SERVICE_LEVEL"
              }
            ]
          },
          {
            "sw_composite_product_id": "superwall.prewarm.secondary",
            "reference_name": "secondary",
            "store_product": {
              "store": "APP_STORE",
              "product_identifier": "superwall.prewarm.secondary"
            },
            "entitlements": [
              {
                "identifier": "prewarm",
                "type": "SERVICE_LEVEL"
              }
            ]
          }
        ],
        "computed_properties": [],
        "local_notifications": [],
        "presentation_delay": 0,
        "presentation_style_v3": {
          "type": "FULLSCREEN"
        },
        "background_color_hex": "#FFFFFF",
        "surveys": []
      }
    ],
    "products_v3": [
      {
        "sw_composite_product_id": "superwall.prewarm.primary",
        "reference_name": "primary",
        "store_product": {
          "store": "APP_STORE",
          "product_identifier": "superwall.prewarm.primary"
        },
        "entitlements": [
          {
            "identifier": "prewarm",
            "type": "SERVICE_LEVEL"
          }
        ]
      },
      {
        "sw_composite_product_id": "superwall.prewarm.secondary",
        "reference_name": "secondary",
        "store_product": {
          "store": "APP_STORE",
          "product_identifier": "superwall.prewarm.secondary"
        },
        "entitlements": [
          {
            "identifier": "prewarm",
            "type": "SERVICE_LEVEL"
          }
        ]
      }
    ],
    "log_level": 0,
    "localization": {
      "locales": [
        {
          "locale": "en"
        }
      ]
    },
    "app_session_timeout_ms": 3600000,
    "toggles": [],
    "disable_preload": {
      "all": true,
      "triggers": []
    },
    "web2app_config": {
      "entitlements_max_age_ms": 86400000,
      "restore_access_url": "https://config-prewarm.invalid/manage"
    },
    "attribution_options": {
      "apple_search_ads": {
        "enabled": false
      },
      "mmp": {
        "enabled": false
      }
    }
  }
  """#
}
