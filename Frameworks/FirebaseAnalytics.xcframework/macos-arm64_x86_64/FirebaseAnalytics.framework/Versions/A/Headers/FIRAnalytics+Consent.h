#import <Foundation/Foundation.h>

#import "FIRAnalytics.h"

NS_ASSUME_NONNULL_BEGIN

/// The type of consent to set. Supported consent types are `ConsentType.adStorage`,
/// `ConsentType.analyticsStorage`, `ConsentType.adUserData`, and `ConsentType.adPersonalization`.
/// Omitting a type retains its previous status.
typedef NSString *FIRConsentType NS_TYPED_ENUM NS_SWIFT_NAME(ConsentType);

/// Enables storage (such as device identifiers) related to advertising.
extern FIRConsentType const FIRConsentTypeAdStorage;

/// Enables storage (such as app identifiers) related to analytics, e.g. visit duration.
extern FIRConsentType const FIRConsentTypeAnalyticsStorage;

/// Sets consent for sending user data to Google for advertising purposes.
extern FIRConsentType const FIRConsentTypeAdUserData;

/// Sets consent for personalized advertising.
extern FIRConsentType const FIRConsentTypeAdPersonalization;

/// The status value of the consent type. Supported statuses are `ConsentStatus.granted` and
/// `ConsentStatus.denied`.
typedef NSString *FIRConsentStatus NS_TYPED_ENUM NS_SWIFT_NAME(ConsentStatus);

/// Consent status indicating consent is denied. For an overview of which data is sent when consent
/// is denied, see [SDK behavior with consent
/// mode](https://developers.google.com/tag-platform/security/concepts/consent-mode#tag-behavior).
extern FIRConsentStatus const FIRConsentStatusDenied;

/// Consent status indicating consent is granted.
extern FIRConsentStatus const FIRConsentStatusGranted;

/// Sets the applicable end user consent state.
@interface FIRAnalytics (Consent)

/// Sets the applicable end user consent state (e.g. for device identifiers) for this app on this
/// device. Use the consent settings to specify individual consent type values. Settings are
/// persisted across app sessions. By default consent types are set to `ConsentStatus.granted`.
///
/// @param consentSettings A Dictionary of consent types. Supported consent type keys are
///   `ConsentType.adStorage`, `ConsentType.analyticsStorage`, `ConsentType.adUserData`, and
///   `ConsentType.adPersonalization`. Valid values are `ConsentStatus.granted` and
///   `ConsentStatus.denied`.
+ (void)setConsent:(NSDictionary<FIRConsentType, FIRConsentStatus> *)consentSettings;

@end

NS_ASSUME_NONNULL_END
