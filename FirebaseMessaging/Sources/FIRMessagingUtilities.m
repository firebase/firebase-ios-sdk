/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"

#import <GoogleUtilities/GULAppEnvironmentUtil.h>
#import <GoogleUtilities/GULUserDefaults.h>
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"

static const uint64_t kBytesToMegabytesDivisor = 1024 * 1024LL;
NSString *const kFIRMessagingInstanceIDUserDefaultsKeyLocale =
    @"com.firebase.instanceid.user_defaults.locale";  // locale key stored in GULUserDefaults
static NSString *const kFIRMessagingAPNSSandboxPrefix = @"s_";
static NSString *const kFIRMessagingAPNSProdPrefix = @"p_";

static NSString *const kFIRMessagingWatchKitExtensionPoint = @"com.apple.watchkit";

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH
static NSString *const kEntitlementsAPSEnvironmentKey = @"Entitlements.aps-environment";
#else
static NSString *const kEntitlementsAPSEnvironmentKey =
    @"Entitlements.com.apple.developer.aps-environment";
#endif
static NSString *const kAPSEnvironmentDevelopmentValue = @"development";

#pragma mark - URL Helpers

NSString *FIRMessagingTokenRegisterServer(void) {
  return @"https://fcmtoken.googleapis.com/register";
}

#pragma mark - Time

int64_t FIRMessagingCurrentTimestampInSeconds(void) {
  return (int64_t)[[NSDate date] timeIntervalSince1970];
}

int64_t FIRMessagingCurrentTimestampInMilliseconds(void) {
  return (int64_t)(FIRMessagingCurrentTimestampInSeconds() * 1000.0);
}

#pragma mark - App Info

NSString *FIRMessagingCurrentAppVersion(void) {
  NSString *version = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
  if (![version length]) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeUtilities000,
                            @"Could not find current app version");
    return @"";
  }
  return version;
}

NSString *FIRMessagingBundleIDByRemovingLastPartFrom(NSString *bundleID) {
  NSString *bundleIDComponentsSeparator = @".";

  NSMutableArray<NSString *> *bundleIDComponents =
      [[bundleID componentsSeparatedByString:bundleIDComponentsSeparator] mutableCopy];
  [bundleIDComponents removeLastObject];

  return [bundleIDComponents componentsJoinedByString:bundleIDComponentsSeparator];
}

NSString *FIRMessagingAppIdentifier(void) {
  NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
#if TARGET_OS_WATCH
  if (FIRMessagingIsWatchKitExtension()) {
    // The code is running in watchKit extension target but the actually bundleID is in the watchKit
    // target. So we need to remove the last part of the bundle ID in watchKit extension to match
    // the one in watchKit target.
    return FIRMessagingBundleIDByRemovingLastPartFrom(bundleID);
  } else {
    return bundleID;
  }
#else
  return bundleID;
#endif
}

NSString *FIRMessagingFirebaseAppID(void) {
  return [FIROptions defaultOptions].googleAppID;
}

BOOL FIRMessagingIsWatchKitExtension(void) {
#if TARGET_OS_WATCH
  NSDictionary<NSString *, id> *infoDict = [[NSBundle mainBundle] infoDictionary];
  NSDictionary<NSString *, id> *extensionAttrDict = infoDict[@"NSExtension"];
  if (!extensionAttrDict) {
    return NO;
  }

  NSString *extensionPointId = extensionAttrDict[@"NSExtensionPointIdentifier"];
  if (extensionPointId) {
    return [extensionPointId isEqualToString:kFIRMessagingWatchKitExtensionPoint];
  } else {
    return NO;
  }
#else
  return NO;
#endif
}

uint64_t FIRMessagingGetFreeDiskSpaceInMB(void) {
  NSError *error;
  NSArray *paths =
      NSSearchPathForDirectoriesInDomains(FIRMessagingSupportedDirectory(), NSUserDomainMask, YES);

  NSDictionary *attributesMap =
      [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject]
                                                              error:&error];
  if (attributesMap) {
    uint64_t totalSizeInBytes __unused = [attributesMap[NSFileSystemSize] longLongValue];
    uint64_t freeSizeInBytes = [attributesMap[NSFileSystemFreeSize] longLongValue];
    FIRMessagingLoggerDebug(
        kFIRMessagingMessageCodeUtilities001, @"Device has capacity %llu MB with %llu MB free.",
        totalSizeInBytes / kBytesToMegabytesDivisor, freeSizeInBytes / kBytesToMegabytesDivisor);
    return ((double)freeSizeInBytes) / kBytesToMegabytesDivisor;
  } else {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeUtilities002,
                            @"Error in retreiving device's free memory %@", error);
    return 0;
  }
}

NSSearchPathDirectory FIRMessagingSupportedDirectory(void) {
#if TARGET_OS_TV
  return NSCachesDirectory;
#else
  return NSApplicationSupportDirectory;
#endif
}

#pragma mark - Locales

NSDictionary *FIRMessagingFirebaselocalesMap(void) {
  return @{
    // Albanian
    @"sq" : @[ @"sq_AL" ],
    // Belarusian
    @"be" : @[ @"be_BY" ],
    // Bulgarian
    @"bg" : @[ @"bg_BG" ],
    // Catalan
    @"ca" : @[ @"ca", @"ca_ES" ],
    // Croatian
    @"hr" : @[ @"hr", @"hr_HR" ],
    // Czech
    @"cs" : @[ @"cs", @"cs_CZ" ],
    // Danish
    @"da" : @[ @"da", @"da_DK" ],
    // Estonian
    @"et" : @[ @"et_EE" ],
    // Finnish
    @"fi" : @[ @"fi", @"fi_FI" ],
    // Hebrew
    @"he" : @[ @"he", @"iw_IL" ],
    // Hindi
    @"hi" : @[ @"hi_IN" ],
    // Hungarian
    @"hu" : @[ @"hu", @"hu_HU" ],
    // Icelandic
    @"is" : @[ @"is_IS" ],
    // Indonesian
    @"id" : @[ @"id", @"in_ID", @"id_ID" ],
    // Irish
    @"ga" : @[ @"ga_IE" ],
    // Korean
    @"ko" : @[ @"ko", @"ko_KR", @"ko-KR" ],
    // Latvian
    @"lv" : @[ @"lv_LV" ],
    // Lithuanian
    @"lt" : @[ @"lt_LT" ],
    // Macedonian
    @"mk" : @[ @"mk_MK" ],
    // Malay
    @"ms" : @[ @"ms_MY" ],
    // Maltese
    @"mt" : @[ @"mt_MT" ],
    // Polish
    @"pl" : @[ @"pl", @"pl_PL", @"pl-PL" ],
    // Romanian
    @"ro" : @[ @"ro", @"ro_RO" ],
    // Russian
    @"ru" : @[ @"ru_RU", @"ru", @"ru_BY", @"ru_KZ", @"ru-RU" ],
    // Slovak
    @"sk" : @[ @"sk", @"sk_SK" ],
    // Slovenian
    @"sl" : @[ @"sl_SI" ],
    // Swedish
    @"sv" : @[ @"sv", @"sv_SE", @"sv-SE" ],
    // Turkish
    @"tr" : @[ @"tr", @"tr-TR", @"tr_TR" ],
    // Ukrainian
    @"uk" : @[ @"uk", @"uk_UA" ],
    // Vietnamese
    @"vi" : @[ @"vi", @"vi_VN" ],
    // The following are groups of locales or locales that sub-divide a
    // language).
    // Arabic
    @"ar" : @[
      @"ar",    @"ar_DZ", @"ar_BH", @"ar_EG", @"ar_IQ", @"ar_JO", @"ar_KW",
      @"ar_LB", @"ar_LY", @"ar_MA", @"ar_OM", @"ar_QA", @"ar_SA", @"ar_SD",
      @"ar_SY", @"ar_TN", @"ar_AE", @"ar_YE", @"ar_GB", @"ar-IQ", @"ar_US"
    ],
    // Simplified Chinese
    @"zh_Hans" : @[ @"zh_CN", @"zh_SG", @"zh-Hans" ],
    // Traditional Chinese
    @"zh_Hant" : @[ @"zh_HK", @"zh_TW", @"zh-Hant", @"zh-HK", @"zh-TW" ],
    // Dutch
    @"nl" : @[ @"nl", @"nl_BE", @"nl_NL", @"nl-NL" ],
    // English
    @"en" : @[
      @"en",    @"en_AU", @"en_CA", @"en_IN", @"en_IE", @"en_MT", @"en_NZ", @"en_PH",
      @"en_SG", @"en_ZA", @"en_GB", @"en_US", @"en_AE", @"en-AE", @"en_AS", @"en-AU",
      @"en_BD", @"en-CA", @"en_EG", @"en_ES", @"en_GB", @"en-GB", @"en_HK", @"en_ID",
      @"en-IN", @"en_NG", @"en-PH", @"en_PK", @"en-SG", @"en-US"
    ],
    // French

    @"fr" :
        @[ @"fr", @"fr_BE", @"fr_CA", @"fr_FR", @"fr_LU", @"fr_CH", @"fr-CA", @"fr-FR", @"fr_MA" ],
    // German
    @"de" : @[ @"de", @"de_AT", @"de_DE", @"de_LU", @"de_CH", @"de-DE" ],
    // Greek
    @"el" : @[ @"el", @"el_CY", @"el_GR" ],
    // Italian
    @"it" : @[ @"it", @"it_IT", @"it_CH", @"it-IT" ],
    // Japanese
    @"ja" : @[ @"ja", @"ja_JP", @"ja_JP_JP", @"ja-JP" ],
    // Norwegian
    @"no" : @[ @"nb", @"no_NO", @"no_NO_NY", @"nb_NO" ],
    // Brazilian Portuguese
    @"pt_BR" : @[ @"pt_BR", @"pt-BR" ],
    // European Portuguese
    @"pt_PT" : @[ @"pt", @"pt_PT", @"pt-PT" ],
    // Serbian
    @"sr" : @[ @"sr_BA", @"sr_ME", @"sr_RS", @"sr_Latn_BA", @"sr_Latn_ME", @"sr_Latn_RS" ],
    // European Spanish
    @"es_ES" : @[ @"es", @"es_ES", @"es-ES" ],
    // Mexican Spanish
    @"es_MX" : @[ @"es-MX", @"es_MX", @"es_US", @"es-US" ],
    // Latin American Spanish
    @"es_419" : @[
      @"es_AR", @"es_BO", @"es_CL", @"es_CO", @"es_CR", @"es_DO", @"es_EC",
      @"es_SV", @"es_GT", @"es_HN", @"es_NI", @"es_PA", @"es_PY", @"es_PE",
      @"es_PR", @"es_UY", @"es_VE", @"es-AR", @"es-CL", @"es-CO"
    ],
    // Thai
    @"th" : @[ @"th", @"th_TH", @"th_TH_TH" ],
  };
}

NSArray *FIRMessagingFirebaseLocales(void) {
  NSMutableArray *locales = [NSMutableArray array];
  NSDictionary *localesMap = FIRMessagingFirebaselocalesMap();
  for (NSString *key in localesMap) {
    [locales addObjectsFromArray:localesMap[key]];
  }
  return locales;
}

NSString *FIRMessagingCurrentLocale(void) {
  NSArray *locales = FIRMessagingFirebaseLocales();
  NSArray *preferredLocalizations =
      [NSBundle preferredLocalizationsFromArray:locales
                                 forPreferences:[NSLocale preferredLanguages]];
  NSString *legalDocsLanguage = [preferredLocalizations firstObject];
  // Use en as the default language
  return legalDocsLanguage ? legalDocsLanguage : @"en";
}

BOOL FIRMessagingHasLocaleChanged(void) {
  NSString *lastLocale = [[GULUserDefaults standardUserDefaults]
      stringForKey:kFIRMessagingInstanceIDUserDefaultsKeyLocale];
  NSString *currentLocale = FIRMessagingCurrentLocale();
  if (lastLocale) {
    if ([currentLocale isEqualToString:lastLocale]) {
      return NO;
    }
  }
  return YES;
}

NSString *FIRMessagingStringForAPNSDeviceToken(NSData *deviceToken) {
  NSMutableString *APNSToken = [NSMutableString string];
  unsigned char *bytes = (unsigned char *)[deviceToken bytes];
  for (int i = 0; i < (int)deviceToken.length; i++) {
    [APNSToken appendFormat:@"%02x", bytes[i]];
  }
  return APNSToken;
}

NSString *FIRMessagingAPNSTupleStringForTokenAndServerType(NSData *deviceToken, BOOL isSandbox) {
  if (deviceToken == nil) {
    // A nil deviceToken leads to an invalid tuple string, so return nil.
    return nil;
  }
  NSString *prefix = isSandbox ? kFIRMessagingAPNSSandboxPrefix : kFIRMessagingAPNSProdPrefix;
  NSString *APNSString = FIRMessagingStringForAPNSDeviceToken(deviceToken);
  NSString *APNSTupleString = [NSString stringWithFormat:@"%@%@", prefix, APNSString];

  return APNSTupleString;
}

BOOL FIRMessagingIsProductionApp(void) {
  const BOOL defaultAppTypeProd = YES;

  NSError *error = nil;
  if ([GULAppEnvironmentUtil isSimulator]) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeInstanceID014,
                            @"Running InstanceID on a simulator doesn't have APNS. "
                            @"Use prod profile by default.");
    return defaultAppTypeProd;
  }

  if ([GULAppEnvironmentUtil isFromAppStore]) {
    // Apps distributed via AppStore or TestFlight use the Production APNS certificates.
    return defaultAppTypeProd;
  }
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
  NSString *path = [[[[NSBundle mainBundle] resourcePath] stringByDeletingLastPathComponent]
      stringByAppendingPathComponent:@"embedded.provisionprofile"];
#elif TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH
  NSString *path = [[[NSBundle mainBundle] bundlePath]
      stringByAppendingPathComponent:@"embedded.mobileprovision"];
#endif

  if ([GULAppEnvironmentUtil isAppStoreReceiptSandbox] && !path.length) {
    // Distributed via TestFlight
    return defaultAppTypeProd;
  }

  NSMutableData *profileData = [NSMutableData dataWithContentsOfFile:path options:0 error:&error];

  if (!profileData.length || error) {
    NSString *errorString =
        [NSString stringWithFormat:@"Error while reading embedded mobileprovision %@", error];
    FIRMessagingLoggerError(kFIRMessagingMessageCodeInstanceID014, @"%@", errorString);
    return defaultAppTypeProd;
  }

  // The "embedded.mobileprovision" sometimes contains characters with value 0, which signals the
  // end of a c-string and halts the ASCII parser, or with value > 127, which violates strict 7-bit
  // ASCII. Replace any 0s or invalid characters in the input.
  uint8_t *profileBytes = (uint8_t *)profileData.bytes;
  for (int i = 0; i < profileData.length; i++) {
    uint8_t currentByte = profileBytes[i];
    if (!currentByte || currentByte > 127) {
      profileBytes[i] = '.';
    }
  }

  NSString *embeddedProfile = [[NSString alloc] initWithBytesNoCopy:profileBytes
                                                             length:profileData.length
                                                           encoding:NSASCIIStringEncoding
                                                       freeWhenDone:NO];

  if (error || !embeddedProfile.length) {
    NSString *errorString =
        [NSString stringWithFormat:@"Error while reading embedded mobileprovision %@", error];
    FIRMessagingLoggerError(kFIRMessagingMessageCodeInstanceID014, @"%@", errorString);
    return defaultAppTypeProd;
  }

  NSScanner *scanner = [NSScanner scannerWithString:embeddedProfile];
  NSString *plistContents;
  if ([scanner scanUpToString:@"<plist" intoString:nil]) {
    if ([scanner scanUpToString:@"</plist>" intoString:&plistContents]) {
      plistContents = [plistContents stringByAppendingString:@"</plist>"];
    }
  }

  if (!plistContents.length) {
    return defaultAppTypeProd;
  }

  NSData *data = [plistContents dataUsingEncoding:NSUTF8StringEncoding];
  if (!data.length) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeInstanceID014,
                            @"Couldn't read plist fetched from embedded mobileprovision");
    return defaultAppTypeProd;
  }

  NSError *plistMapError;
  id plistData = [NSPropertyListSerialization propertyListWithData:data
                                                           options:NSPropertyListImmutable
                                                            format:nil
                                                             error:&plistMapError];
  if (plistMapError || ![plistData isKindOfClass:[NSDictionary class]]) {
    NSString *errorString =
        [NSString stringWithFormat:@"Error while converting assumed plist to dict %@",
                                   plistMapError.localizedDescription];
    FIRMessagingLoggerError(kFIRMessagingMessageCodeInstanceID014, @"%@", errorString);
    return defaultAppTypeProd;
  }
  NSDictionary *plistMap = (NSDictionary *)plistData;

  if ([plistMap valueForKeyPath:@"ProvisionedDevices"]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeInstanceID012,
                            @"Provisioning profile has specifically provisioned devices, "
                            @"most likely a Dev profile.");
  }

  NSString *apsEnvironment = [plistMap valueForKeyPath:kEntitlementsAPSEnvironmentKey];
  NSString *debugString __unused =
      [NSString stringWithFormat:@"APNS Environment in profile: %@", apsEnvironment];
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeInstanceID013, @"%@", debugString);

  // No aps-environment in the profile.
  if (!apsEnvironment.length) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeInstanceID014,
                            @"No aps-environment set. If testing on a device APNS is not "
                            @"correctly configured. Please recheck your provisioning "
                            @"profiles. If testing on a simulator this is fine since APNS "
                            @"doesn't work on the simulator.");
    return defaultAppTypeProd;
  }

  if ([apsEnvironment isEqualToString:kAPSEnvironmentDevelopmentValue]) {
    return NO;
  }

  return defaultAppTypeProd;
}

BOOL FIRMessagingIsSandboxApp(void) {
  static BOOL isSandboxApp = YES;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    isSandboxApp = !FIRMessagingIsProductionApp();
  });
  return isSandboxApp;
}
