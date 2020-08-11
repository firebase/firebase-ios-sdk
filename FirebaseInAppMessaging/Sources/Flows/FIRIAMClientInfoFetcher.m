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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"

#import "FirebaseInAppMessaging/Sources/FIRCore+InAppMessaging.h"
#import "FirebaseInAppMessaging/Sources/FIRInAppMessagingPrivate.h"
#import "FirebaseInAppMessaging/Sources/Private/Analytics/FIRIAMClientInfoFetcher.h"
#import "FirebaseInAppMessaging/Sources/Runtime/FIRIAMSDKRuntimeErrorCodes.h"

@interface FIRIAMClientInfoFetcher ()

@property(nonatomic, strong, nullable, readonly) FIRInstallations *installations;

@end

@implementation FIRIAMClientInfoFetcher

- (instancetype)initWithFirebaseInstallations:(FIRInstallations *)installations {
  if (self = [super init]) {
    _installations = installations;
  }
  return self;
}

- (void)fetchFirebaseInstallationDataWithProjectNumber:(NSString *)projectNumber
                                        withCompletion:
                                            (void (^)(NSString *_Nullable FID,
                                                      NSString *_Nullable FISToken,
                                                      NSError *_Nullable error))completion {
  if (!self.installations) {
    NSString *errorDesc = @"Couldn't generate Firebase Installation info";
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM190010", @"%@", errorDesc);
    NSError *error = [NSError errorWithDomain:kFirebaseInAppMessagingErrorDomain
                                         code:FIRIAMSDKRuntimeErrorNoFirebaseInstallationsObject
                                     userInfo:@{NSLocalizedDescriptionKey : errorDesc}];
    completion(nil, nil, error);
    return;
  }

  [self.installations authTokenWithCompletion:^(
                          FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                          NSError *_Nullable error) {
    if (error) {
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM190006", @"Error in fetching FIS token: %@",
                    error.localizedDescription);
      completion(nil, nil, error);
    } else {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM190007", @"Successfully generated FIS token");

      [self.installations
          installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
            if (error) {
              FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM190008", @"Error in fetching FID: %@",
                            error.localizedDescription);
              completion(nil, tokenResult.authToken, error);
            } else {
              FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM190009",
                          @"Successfully in fetching both FID as %@ and FIS token as %@",
                          identifier, tokenResult.authToken);
              completion(identifier, tokenResult.authToken, nil);
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

#endif  // TARGET_OS_IOS
