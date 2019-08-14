#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RCNDeviceModel) {
  RCNDeviceModelOther,
  RCNDeviceModelPhone,
  RCNDeviceModelTablet,
  RCNDeviceModelTV,
  RCNDeviceModelGlass,
  RCNDeviceModelCar,
  RCNDeviceModelWearable,
};

/// CocoaPods SDK version
NSString *FIRRemoteConfigPodVersion();

/// App version.
NSString *FIRRemoteConfigAppVersion();

/// Device country, in lowercase.
NSString *FIRRemoteConfigDeviceCountry();

/// Device locale, in language_country format, e.g. en_US.
NSString *FIRRemoteConfigDeviceLocale();

/// Device subtype.
RCNDeviceModel FIRRemoteConfigDeviceSubtype();

/// Device timezone.
NSString *FIRRemoteConfigTimezone();

/// SDK version. This is different than CocoaPods SDK version.
/// It is used for config server to keep track iOS client version.
/// major * 10000 + minor + 100 + patch.
int FIRRemoteConfigSDKVersion();

/// Update device context to the given dictionary.
NSMutableDictionary *FIRRemoteConfigDeviceContextWithProjectIdentifier(
    NSString *GMPProjectIdentifier);

/// Check whether client has changed device context, including app version,
/// iOS version, device country etc. This is used to determine whether to throttle.
BOOL FIRRemoteConfigHasDeviceContextChanged(NSDictionary *deviceContext,
                                            NSString *GMPProjectIdentifier);
