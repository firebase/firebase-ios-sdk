import Foundation
import GoogleUtilities
class RCNDevice {
    enum Model {
        case Phone
        case Tablet
        case Other
    }
    static func appVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    static func appBuildVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    static func podVersion() -> String {
        return FIRFirebaseVersion();
    }

    static func deviceSubtype() -> Model {
        let model = GULAppEnvironmentUtil.deviceModel()
        if model.hasPrefix("iPhone") {
            return .Phone
        }
        if model == "iPad" {
            return .Tablet
        }
        return .Other
    }

    static func deviceCountry() -> String {
        return (Locale.current.object(forKey: .countryCode) as? String ?? "").lowercased()
    }

    static func firebaseLocaleMap() -> [String: [String]] {
        return [
          // Albanian
          "sq" : [ "sq_AL" ],
          // Belarusian
          "be" : [ "be_BY" ],
          // Bulgarian
          "bg" : [ "bg_BG" ],
          // Catalan
          "ca" : [ "ca", "ca_ES" ],
          // Croatian
          "hr" : [ "hr", "hr_HR" ],
          // Czech
          "cs" : [ "cs", "cs_CZ" ],
          // Danish
          "da" : [ "da", "da_DK" ],
          // Estonian
          "et" : [ "et_EE" ],
          // Finnish
          "fi" : [ "fi", "fi_FI" ],
          // Hebrew
          "he" : [ "he", "iw_IL" ],
          // Hungarian
          "hu" : [ "hu", "hu_HU" ],
          // Icelandic
          "is" : [ "is_IS" ],
          // Indonesian
          "id" : [ "id", "in_ID", "id_ID" ],
          // Irish
          "ga" : [ "ga_IE" ],
          // Korean
          "ko" : [ "ko", "ko_KR", "ko-KR" ],
          // Latvian
          "lv" : [ "lv_LV" ],
          // Lithuanian
          "lt" : [ "lt_LT" ],
          // Macedonian
          "mk" : [ "mk_MK" ],
          // Malay
          "ms" : [ "ms_MY" ],
          // Maltese
          "mt" : [ "mt_MT" ],
          // Polish
          "pl" : [ "pl", "pl_PL", "pl-PL" ],
          // Romanian
          "ro" : [ "ro", "ro_RO" ],
          // Russian
          "ru" : [ "ru_RU", "ru", "ru_BY", "ru_KZ", "ru-RU" ],
          // Slovak
          "sk" : [ "sk", "sk_SK" ],
          // Slovenian
          "sl" : [ "sl_SI" ],
          // Swedish
          "sv" : [ "sv", "sv_SE", "sv-SE" ],
          // Turkish
          "tr" : [ "tr", "tr-TR", "tr_TR" ],
          // Ukrainian
          "uk" : [ "uk", "uk_UA" ],
          // Vietnamese
          "vi" : [ "vi", "vi_VN" ],
          // The following are groups of locales or locales that sub-divide a
          // language).
          // Arabic
          "ar" : [
            "ar",    "ar_DZ", "ar_BH", "ar_EG", "ar_IQ", "ar_JO", "ar_KW",
            "ar_LB", "ar_LY", "ar_MA", "ar_OM", "ar_QA", "ar_SA", "ar_SD",
            "ar_SY", "ar_TN", "ar_AE", "ar_YE", "ar_GB", "ar-IQ", "ar_US"
          ],
          // Simplified Chinese
          "zh_Hans" : [ "zh_CN", "zh_SG", "zh-Hans" ],
          // Traditional Chinese
          // Remove zh_HK until console added to the list. Otherwise client sends
          // zh_HK and server/console falls back to zh.
          // @"zh_Hant" : [ "zh_HK", "zh_TW", "zh-Hant", "zh-HK", "zh-TW" ],
          "zh_Hant" : [ "zh_TW", "zh-Hant", "zh-TW" ],
          // Dutch
          "nl" : [ "nl", "nl_BE", "nl_NL", "nl-NL" ],
          // English
          "en" : [
            "en",    "en_AU", "en_CA", "en_IN", "en_IE", "en_MT", "en_NZ", "en_PH",
            "en_SG", "en_ZA", "en_GB", "en_US", "en_AE", "en-AE", "en_AS", "en-AU",
            "en_BD", "en-CA", "en_EG", "en_ES", "en_GB", "en-GB", "en_HK", "en_ID",
            "en-IN", "en_NG", "en-PH", "en_PK", "en-SG", "en-US"
          ],
          // French
          "fr" :
              [ "fr", "fr_BE", "fr_CA", "fr_FR", "fr_LU", "fr_CH", "fr-CA", "fr-FR", "fr_MA" ],
          // German
          "de" : [ "de", "de_AT", "de_DE", "de_LU", "de_CH", "de-DE" ],
          // Greek
          "el" : [ "el", "el_CY", "el_GR" ],
          // India
          "hi_IN" :
              [ "hi_IN", "ta_IN", "te_IN", "mr_IN", "bn_IN", "gu_IN", "kn_IN", "pa_Guru_IN" ],
          // Italian
          "it" : [ "it", "it_IT", "it_CH", "it-IT" ],
          // Japanese
          "ja" : [ "ja", "ja_JP", "ja_JP_JP", "ja-JP" ],
          // Norwegian
          "no" : [ "nb", "no_NO", "no_NO_NY", "nb_NO" ],
          // Brazilian Portuguese
          "pt_BR" : [ "pt_BR", "pt-BR" ],
          // European Portuguese
          "pt_PT" : [ "pt", "pt_PT", "pt-PT" ],
          // Serbian
          "sr" : [ "sr_BA", "sr_ME", "sr_RS", "sr_Latn_BA", "sr_Latn_ME", "sr_Latn_RS" ],
          // Spanish
          "es_ES" : [ "es", "es_ES", "es-ES" ],
          // Mexican Spanish
          "es_MX" : [ "es-MX", "es_MX", "es_US", "es-US" ],
          // Latin American Spanish
          "es_419" : [
            "es_AR", "es_BO", "es_CL", "es_CO", "es_CR", "es_DO", "es_EC",
            "es_SV", "es_GT", "es_HN", "es_NI", "es_PA", "es_PY", "es_PE",
            "es_PR", "es_UY", "es_VE", "es-AR", "es-CL", "es-CO"
          ],
          // Thai
          "th" : [ "th", "th_TH", "th_TH_TH" ],
        ];
    }

    static func deviceLocale() -> String {
        let locales = FIRRemoteConfigAppManagerLocales()
        let preferredLocalizations = NSBundle.preferredLocalizations(from: locales, forPreferences: Locale.preferredLanguages)
        // Use en as the default language
        return legalDocsLanguage ?? "en"
    }

    static func timezone() -> String {
        let timezone = TimeZone.system
        return timezone.identifier
    }
    
    static func deviceContextWithProjectIdentifier(GMPProjectIdentifier:String) -> NSMutableDictionary<String,Any> {
        let deviceContext = NSMutableDictionary<String, Any>()
        deviceContext[RCNConstants.RCNDeviceContextKeyVersion] = FIRRemoteConfigAppVersion()
        deviceContext[RCNConstants.RCNDeviceContextKeyBuild] = FIRRemoteConfigAppBuildVersion()
        deviceContext[RCNConstants.RCNDeviceContextKeyOSVersion] = GULAppEnvironmentUtil.systemVersion()
        deviceContext[RCNConstants.RCNDeviceContextKeyDeviceLocale] = FIRRemoteConfigDeviceLocale()
        deviceContext[RCNConstants.RCNDeviceContextKeyGMPProjectIdentifier] = GMPProjectIdentifier
        return deviceContext
    }
    
    static func hasDeviceContextChanged(deviceContext: [String : Any], GMPProjectIdentifier: String) -> Bool {
        if (!(deviceContext[RCNConstants.RCNDeviceContextKeyVersion] as! String).isEqual(FIRRemoteConfigAppVersion()) {
            return true;
        }
        if (!(deviceContext[RCNDeviceContextKeyBuild] as! String).isEqual(FIRRemoteConfigAppBuildVersion()) {
            return true
        }
        if !(deviceContext[RCNDeviceContextKeyOSVersion] as! String).isEqual(GULAppEnvironmentUtil.systemVersion()) {
            return true
        }
        if !(deviceContext[RCNDeviceContextKeyDeviceLocale] as! String).isEqual(FIRRemoteConfigDeviceLocale()) {
            return true
        }
        // GMP project id is optional.
        if deviceContext[RCNDeviceContextKeyGMPProjectIdentifier] != nil &&
            !((deviceContext[RCNDeviceContextKeyGMPProjectIdentifier] as! String).isEqual(GMPProjectIdentifier)) {
            return true
        }
        return false
    }
}
