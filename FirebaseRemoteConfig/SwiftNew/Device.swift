// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

import FirebaseCore
import GoogleUtilities

// TODO: convert to enum
@objc public class Device: NSObject {
  static let RCNDeviceContextKeyVersion = "app_version"
  static let RCNDeviceContextKeyBuild = "app_build"
  static let RCNDeviceContextKeyOSVersion = "os_version"
  static let RCNDeviceContextKeyDeviceLocale = "device_locale"
  static let RCNDeviceContextKeyLocaleLanguage = "locale_language"
  static let RCNDeviceContextKeyGMPProjectIdentifier = "GMP_project_Identifier"

  @objc public static func remoteConfigAppVersion() -> String {
    return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
  }

  @objc public static func remoteConfigAppBuildVersion() -> String {
    return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
  }

  @objc public static func remoteConfigPodVersion() -> String {
    return FirebaseVersion()
  }

  @objc public enum DeviceModel: Int {
    case other
    case phone
    case tablet
    case tv
    case glass
    case car
    case wearable
  }

  @objc public static func remoteConfigDeviceSubtype() -> DeviceModel {
    guard let model = GULAppEnvironmentUtil.deviceModel() else {
      return .other
    }
    if model.hasPrefix("iPhone") {
      return .phone
    }
    if model == "iPad" {
      return .tablet
    }
    return .other
  }

  @objc public static func remoteConfigDeviceCountry() -> String {
    return Locale.current.regionCode?.lowercased() ?? ""
  }

  @objc public static let firebaseLocaleMap = [
    // Albanian
    "sq": ["sq_AL"],
    // Belarusian
    "be": ["be_BY"],
    // Bulgarian
    "bg": ["bg_BG"],
    // Catalan
    "ca": ["ca", "ca_ES"],
    // Croatian
    "hr": ["hr", "hr_HR"],
    // Czech
    "cs": ["cs", "cs_CZ"],
    // Danish
    "da": ["da", "da_DK"],
    // Estonian
    "et": ["et_EE"],
    // Finnish
    "fi": ["fi", "fi_FI"],
    // Hebrew
    "he": ["he", "iw_IL"],
    // Hindi
    "hi": ["hi_IN"],
    // Hungarian
    "hu": ["hu", "hu_HU"],
    // Icelandic
    "is": ["is_IS"],
    // Indonesian
    "id": ["id", "in_ID", "id_ID"],
    // Irish
    "ga": ["ga_IE"],
    // Korean
    "ko": ["ko", "ko_KR", "ko-KR"],
    // Latvian
    "lv": ["lv_LV"],
    // Lithuanian
    "lt": ["lt_LT"],
    // Macedonian
    "mk": ["mk_MK"],
    // Malay
    "ms": ["ms_MY"],
    // Maltese
    "mt": ["mt_MT"],
    // Polish
    "pl": ["pl", "pl_PL", "pl-PL"],
    // Romanian
    "ro": ["ro", "ro_RO"],
    // Russian
    "ru": ["ru_RU", "ru", "ru_BY", "ru_KZ", "ru-RU"],
    // Slovak
    "sk": ["sk", "sk_SK"],
    // Slovenian
    "sl": ["sl_SI"],
    // Swedish
    "sv": ["sv", "sv_SE", "sv-SE"],
    // Turkish
    "tr": ["tr", "tr-TR", "tr_TR"],
    // Ukrainian
    "uk": ["uk", "uk_UA"],
    // Vietnamese
    "vi": ["vi", "vi_VN"],
    // The following are groups of locales or locales that subdivide a
    // language).
    // Arabic
    "ar": [
      "ar", "ar_DZ", "ar_BH", "ar_EG", "ar_IQ", "ar_JO", "ar_KW",
      "ar_LB", "ar_LY", "ar_MA", "ar_OM", "ar_QA", "ar_SA", "ar_SD",
      "ar_SY", "ar_TN", "ar_AE", "ar_YE", "ar_GB", "ar-IQ", "ar_US",
    ],
    // Simplified Chinese
    "zh_Hans": ["zh_CN", "zh_SG", "zh-Hans"],
    // Traditional Chinese
    // Remove zh_HK until console added to the list. Otherwise client sends
    // zh_HK and server/console falls back to zh.
    // @"zh_Hant" : @[ @"zh_HK", @"zh_TW", @"zh-Hant", @"zh-HK", @"zh-TW" ],
    "zh_Hant": ["zh_TW", "zh-Hant", "zh-TW"],
    // Dutch
    "nl": ["nl", "nl_BE", "nl_NL", "nl-NL"],
    // English
    "en": [
      "en", "en_AU", "en_CA", "en_IN", "en_IE", "en_MT", "en_NZ", "en_PH",
      "en_SG", "en_ZA", "en_GB", "en_US", "en_AE", "en-AE", "en_AS", "en-AU",
      "en_BD", "en-CA", "en_EG", "en_ES", "en_GB", "en-GB", "en_HK", "en_ID",
      "en-IN", "en_NG", "en-PH", "en_PK", "en-SG", "en-US",
    ],
    // French
    "fr":
      [
        "fr", "fr_BE", "fr_CA", "fr_FR", "fr_LU", "fr_CH", "fr-CA", "fr-FR", "fr_MA",
      ],
    // German
    "de": ["de", "de_AT", "de_DE", "de_LU", "de_CH", "de-DE"],
    // Greek
    "el": ["el", "el_CY", "el_GR"],
    // Italian
    "it": ["it", "it_IT", "it_CH", "it-IT"],
    // Japanese
    "ja": ["ja", "ja_JP", "ja_JP_JP", "ja-JP"],
    // Norwegian
    "no": ["nb", "no_NO", "no_NO_NY", "nb_NO"],
    // Brazilian Portuguese
    "pt_BR": ["pt_BR", "pt-BR"],
    // European Portuguese
    "pt_PT": ["pt", "pt_PT", "pt-PT"],
    // Serbian
    "sr": ["sr_BA", "sr_ME", "sr_RS", "sr_Latn_BA", "sr_Latn_ME", "sr_Latn_RS"],
    // European Spanish
    "es_ES": ["es", "es_ES", "es-ES"],
    // Mexican Spanish
    "es_MX": ["es-MX", "es_MX", "es_US", "es-US"],
    // Latin American Spanish
    "es_419": [
      "es_AR", "es_BO", "es_CL", "es_CO", "es_CR", "es_DO", "es_EC",
      "es_SV", "es_GT", "es_HN", "es_NI", "es_PA", "es_PY", "es_PE",
      "es_PR", "es_UY", "es_VE", "es-AR", "es-CL", "es-CO",
    ],
    // Thai
    "th": ["th", "th_TH", "th_TH_TH"],
  ]

  private static func firebaseLocales() -> [String] {
    var locales = [String]()
    let localesMap = firebaseLocaleMap
    for (_, value) in localesMap {
      locales.append(contentsOf: value)
    }
    return locales
  }

  @objc public static func remoteConfigDeviceLocale() -> String {
    let locales = firebaseLocales()
    let preferredLocalizations = Bundle.preferredLocalizations(
      from: locales,
      forPreferences: Locale.preferredLanguages
    )
    return preferredLocalizations.first ?? "en"
  }

  @objc public static func remoteConfigTimezone() -> String {
    return TimeZone.current.identifier
  }

  @objc public static func remoteConfigDeviceContext(with projectIdentifier: String?)
    -> [String: Any] {
    var deviceContext: [String: Any] = [:]
    deviceContext[RCNDeviceContextKeyVersion] = remoteConfigAppVersion()
    deviceContext[RCNDeviceContextKeyBuild] = remoteConfigAppBuildVersion()
    deviceContext[RCNDeviceContextKeyOSVersion] = GULAppEnvironmentUtil.systemVersion()
    deviceContext[RCNDeviceContextKeyDeviceLocale] = remoteConfigDeviceLocale()
    // NSDictionary setObject will fail if there's no GMP project ID, must check ahead.
    if let GMPProjectIdentifier = projectIdentifier {
      deviceContext[RCNDeviceContextKeyGMPProjectIdentifier] = GMPProjectIdentifier
    }
    return deviceContext
  }

  @objc public static func remoteConfigHasDeviceContextChanged(_ deviceContext: [String: String],
                                                               projectIdentifier: String?) -> Bool {
    guard let version = deviceContext[RCNDeviceContextKeyVersion],
          let build = deviceContext[RCNDeviceContextKeyBuild],
          let osVersion = deviceContext[RCNDeviceContextKeyOSVersion],
          let locale = deviceContext[RCNDeviceContextKeyDeviceLocale] else {
      return true
    }
    if version != remoteConfigAppVersion() ||
      build != remoteConfigAppBuildVersion() ||
      osVersion != GULAppEnvironmentUtil.systemVersion() ||
      locale != remoteConfigDeviceLocale() {
      return true
    }
    if let gmpProjectIdentifier = deviceContext[RCNDeviceContextKeyGMPProjectIdentifier] {
      return gmpProjectIdentifier != projectIdentifier
    }
    return false
  }
}
