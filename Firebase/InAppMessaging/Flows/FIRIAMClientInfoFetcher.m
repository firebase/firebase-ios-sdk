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

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRLogger.h>
#import <FirebaseInstanceID/FirebaseInstanceID.h>

#import "FIRCore+InAppMessaging.h"
#import "FIRIAMClientInfoFetcher.h"

// declaratons for FIRInstanceID SDK
@implementation FIRIAMClientInfoFetcher
- (void)fetchFirebaseIIDDataWithProjectNumber:(NSString *)projectNumber
                               withCompletion:(void (^)(NSString *_Nullable iid,
                                                        NSString *_Nullable token,
                                                        NSError *_Nullable error))completion {
  FIRInstanceID *iid = [FIRInstanceID instanceID];

  // tokenWithAuthorizedEntity would only communicate with server on periodical cycles.
  // For other times, it's going to fetch from local cache, so it's not causing any performance
  // concern in the fetch flow.
  [iid tokenWithAuthorizedEntity:projectNumber
                           scope:@"fiam"
                         options:nil
                         handler:^(NSString *_Nullable token, NSError *_Nullable error) {
                           if (error) {
                             FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM190001",
                                           @"Error in fetching iid token: %@",
                                           error.localizedDescription);
                             completion(nil, nil, error);
                           } else {
                             FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM190002",
                                         @"Successfully generated iid token");
                             // now we can go ahead to fetch the id
                             [iid getIDWithHandler:^(NSString *_Nullable identity,
                                                     NSError *_Nullable error) {
                               if (error) {
                                 FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM190004",
                                               @"Error in fetching iid value: %@",
                                               error.localizedDescription);
                               } else {
                                 FIRLogDebug(
                                     kFIRLoggerInAppMessaging, @"I-IAM190005",
                                     @"Successfully in fetching both iid value as %@ and iid token"
                                      " as %@",
                                     identity, token);
                                 completion(identity, token, nil);
                               }
                             }];
                           }
                         }];
}

- (nullable NSString *)getDeviceLanguageCode {
  // No caching since it's requested at pretty low frequency and we get the benefit of seeing
  // updated info the setting has changed
  NSArray<NSString *> *preferredLanguages = [NSLocale preferredLanguages];
  return preferredLanguages.firstObject;
}

- (nullable NSString *)getAppVersion {
  // Since this won't change, read it once in the whole life-cycle of the app and cache its value
  static NSString *appVersion = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  });
  return appVersion;
}

- (nullable NSString *)getOSVersion {
  // Since this won't change, read it once in the whole life-cycle of the app and cache its value
  static NSString *OSVersion = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSOperatingSystemVersion systemVersion = [NSProcessInfo processInfo].operatingSystemVersion;
    OSVersion = [NSString stringWithFormat:@"%ld.%ld.%ld", (long)systemVersion.majorVersion,
                                           (long)systemVersion.minorVersion,
                                           (long)systemVersion.patchVersion];
  });
  return OSVersion;
}

- (nullable NSString *)getOSMajorVersion {
  NSArray *versionItems = [[self getOSVersion] componentsSeparatedByString:@"."];

  if (versionItems.count > 0) {
    return (NSString *)versionItems[0];
  } else {
    return nil;
  }
}

- (nullable NSString *)getTimezone {
  // No caching to deal with potential changes.
  return [NSTimeZone localTimeZone].name;
}

// extract macro value into a C string
#define STR_FROM_MACRO(x) #x
#define STR(x) STR_FROM_MACRO(x)

- (NSString *)getIAMSDKVersion {
  // FIRInAppMessaging_LIB_VERSION macro comes from pod definition
  return [NSString stringWithUTF8String:STR(FIRInAppMessaging_LIB_VERSION)];
}
@end
