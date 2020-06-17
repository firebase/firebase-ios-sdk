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

#import "FIRMessagingCheckinPreferences.h"

#import "FIRMessagingCheckinService.h"
#import "FIRMessagingUtilities.h"
#import "GoogleUtilities/UserDefaults/Private/GULUserDefaults.h"

const NSTimeInterval kFIRMessagingDefaultCheckinInterval = 7 * 24 * 60 * 60;  // 7 days.

@interface FIRMessagingCheckinPreferences ()

@property(nonatomic, readwrite, copy) NSString *deviceID;
@property(nonatomic, readwrite, copy) NSString *secretToken;
@property(nonatomic, readwrite, copy) NSString *digest;
@property(nonatomic, readwrite, copy) NSString *versionInfo;
@property(nonatomic, readwrite, copy) NSString *deviceDataVersion;

@property(nonatomic, readwrite, strong) NSMutableDictionary *gServicesData;
@property(nonatomic, readwrite, assign) int64_t lastCheckinTimestampMillis;

// This flag indicates that we have already saved the above deviceID and secret
// to our keychain and hence we don't need to save again. This is helpful since
// on checkin refresh we can avoid writing to the Keychain which can sometimes
// be very buggy. For info check this https://forums.developer.apple.com/thread/4743
@property(nonatomic, readwrite, assign) BOOL hasPreCachedAuthCredentials;

@end

@implementation FIRMessagingCheckinPreferences

- (NSDictionary *)checkinPlistContents {
  NSMutableDictionary *checkinPlistContents = [NSMutableDictionary dictionary];
  checkinPlistContents[kFIRMessagingDigestStringKey] = self.digest ?: @"";
  checkinPlistContents[kFIRMessagingVersionInfoStringKey] = self.versionInfo ?: @"";
  checkinPlistContents[kFIRMessagingDeviceDataVersionKey] = self.deviceDataVersion ?: @"";
  checkinPlistContents[kFIRMessagingLastCheckinTimeKey] = @(self.lastCheckinTimestampMillis);
  checkinPlistContents[kFIRMessagingGServicesDictionaryKey] =
      [self.gServicesData count] ? self.gServicesData : @{};
  return checkinPlistContents;
}

- (BOOL)hasCheckinInfo {
  return (self.deviceID.length && self.secretToken.length);
}

- (BOOL)hasValidCheckinInfo {
  int64_t currentTimestampInMillis = FIRMessagingCurrentTimestampInMilliseconds();
  int64_t timeSinceLastCheckinInMillis = currentTimestampInMillis - self.lastCheckinTimestampMillis;

  BOOL hasCheckinInfo = [self hasCheckinInfo];
  NSString *lastLocale =
      [[GULUserDefaults standardUserDefaults] stringForKey:kFIRMessagingUserDefaultsKeyLocale];
  // If it's app's first time open and checkin is already fetched and no locale information is
  // stored, then checkin info is valid. We should not checkin again because locale is considered
  // "changed".
  if (hasCheckinInfo && !lastLocale) {
    NSString *currentLocale = FIRMessagingCurrentLocale();
    [[GULUserDefaults standardUserDefaults] setObject:currentLocale
                                               forKey:kFIRMessagingUserDefaultsKeyLocale];
    return YES;
  }

  // If locale has changed, checkin info is no longer valid.
  // Also update locale information if changed. (Only do it here not in token refresh)
  if (FIRMessagingHasLocaleChanged()) {
    NSString *currentLocale = FIRMessagingCurrentLocale();
    [[GULUserDefaults standardUserDefaults] setObject:currentLocale
                                               forKey:kFIRMessagingUserDefaultsKeyLocale];
    return NO;
  }

  return (hasCheckinInfo &&
          (timeSinceLastCheckinInMillis / 1000.0 < kFIRMessagingDefaultCheckinInterval));
}

- (void)setHasPreCachedAuthCredentials:(BOOL)hasPreCachedAuthCredentials {
  _hasPreCachedAuthCredentials = hasPreCachedAuthCredentials;
}

@end
