/*
 * Copyright 2019 Google
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

#import "FirebaseRemoteConfig/Sources/RCNDevice.h"

#import <sys/utsname.h>

#import <GoogleUtilities/GULAppEnvironmentUtil.h>
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"

#define STR(x) STR_EXPAND(x)
#define STR_EXPAND(x) #x

static NSString *const RCNDeviceContextKeyVersion = @"app_version";
static NSString *const RCNDeviceContextKeyBuild = @"app_build";
static NSString *const RCNDeviceContextKeyOSVersion = @"os_version";
static NSString *const RCNDeviceContextKeyDeviceLocale = @"device_locale";
static NSString *const RCNDeviceContextKeyLocaleLanguage = @"locale_language";
static NSString *const RCNDeviceContextKeyGMPProjectIdentifier = @"GMP_project_Identifier";

NSString *FIRRemoteConfigAppVersion(void) {
  return [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
}

NSString *FIRRemoteConfigAppBuildVersion(void) {
  return [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
}

NSString *FIRRemoteConfigPodVersion(void) {
  return FIRFirebaseVersion();
}

RCNDeviceModel FIRRemoteConfigDeviceSubtype(void) {
  NSString *model = [GULAppEnvironmentUtil deviceModel];
  if ([model hasPrefix:@"iPhone"]) {
    return RCNDeviceModelPhone;
  }
  if ([model isEqualToString:@"iPad"]) {
    return RCNDeviceModelTablet;
  }
  return RCNDeviceModelOther;
}

NSString *FIRRemoteConfigDeviceCountry(void) {
  return [[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode] lowercaseString];
}

NSArray<NSString *> *FIRRemoteConfigAppManagerLocales(void) {
  // get the list of language codes
  NSArray *locales = [NSLocale ISOLanguageCodes];

  return locales;
}
NSString *FIRRemoteConfigDeviceLocale(void) {
  NSArray<NSString *> *locales = FIRRemoteConfigAppManagerLocales();
  NSArray<NSString *> *preferredLocalizations =
      [NSBundle preferredLocalizationsFromArray:locales
                                 forPreferences:[NSLocale preferredLanguages]];
  NSString *legalDocsLanguage = [preferredLocalizations firstObject];
  // Use en as the default language
  return legalDocsLanguage ? legalDocsLanguage : @"en";
}

NSString *FIRRemoteConfigTimezone(void) {
  NSTimeZone *timezone = [NSTimeZone systemTimeZone];
  return timezone.name;
}

NSMutableDictionary *FIRRemoteConfigDeviceContextWithProjectIdentifier(
    NSString *GMPProjectIdentifier) {
  NSMutableDictionary *deviceContext = [[NSMutableDictionary alloc] init];
  deviceContext[RCNDeviceContextKeyVersion] = FIRRemoteConfigAppVersion();
  deviceContext[RCNDeviceContextKeyBuild] = FIRRemoteConfigAppBuildVersion();
  deviceContext[RCNDeviceContextKeyOSVersion] = [GULAppEnvironmentUtil systemVersion];
  deviceContext[RCNDeviceContextKeyDeviceLocale] = FIRRemoteConfigDeviceLocale();
  // NSDictionary setObjectForKey will fail if there's no GMP project ID, must check ahead.
  if (GMPProjectIdentifier) {
    deviceContext[RCNDeviceContextKeyGMPProjectIdentifier] = GMPProjectIdentifier;
  }
  return deviceContext;
}

BOOL FIRRemoteConfigHasDeviceContextChanged(NSDictionary *deviceContext,
                                            NSString *GMPProjectIdentifier) {
  if (![deviceContext[RCNDeviceContextKeyVersion] isEqual:FIRRemoteConfigAppVersion()]) {
    return YES;
  }
  if (![deviceContext[RCNDeviceContextKeyBuild] isEqual:FIRRemoteConfigAppBuildVersion()]) {
    return YES;
  }
  if (![deviceContext[RCNDeviceContextKeyOSVersion]
          isEqual:[GULAppEnvironmentUtil systemVersion]]) {
    return YES;
  }
  if (![deviceContext[RCNDeviceContextKeyDeviceLocale] isEqual:FIRRemoteConfigDeviceLocale()]) {
    return YES;
  }
  // GMP project id is optional.
  if (deviceContext[RCNDeviceContextKeyGMPProjectIdentifier] &&
      ![deviceContext[RCNDeviceContextKeyGMPProjectIdentifier] isEqual:GMPProjectIdentifier]) {
    return YES;
  }
  return NO;
}
