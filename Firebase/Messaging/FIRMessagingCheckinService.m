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

#import "FIRMessagingCheckinService.h"

#import "FIRMessagingUtilities.h"
#import "NSError+FIRMessaging.h"

// TODO Internal InstanceID
//#import "googlemac/iPhone/InstanceID/Firebase/Lib/Source/FIRInstanceID+Private.h"
//#import "googlemac/iPhone/InstanceID/Firebase/Lib/Source/FIRInstanceIDCheckinPreferences.h"

NSString *const kFIRMessagingDeviceAuthIdKey = @"GMSInstanceIDDeviceAuthIdKey";
NSString *const kFIRMessagingSecretTokenKey = @"GMSInstanceIDSecretTokenKey";

NSString *const kFIRMessagingLastCheckinTimeKey = @"GMSInstanceIDLastCheckinTimestampKey";
NSString *const kFIRMessagingDigestStringKey = @"GMSInstanceIDDigestKey";
NSString *const kFIRMessagingVersionInfoStringKey = @"GMSInstanceIDVersionInfo";
NSString *const kFIRMessagingGServicesDictionaryKey = @"GMSInstanceIDGServicesData";

@interface FIRMessagingCheckinService ()

//@property(nonatomic, readwrite, strong) FIRInstanceIDCheckinPreferences *checkinPreferences;

@end

@implementation FIRMessagingCheckinService;

- (BOOL)tryToLoadPrefetchedCheckinPreferences {
//  FIRInstanceIDCheckinPreferences *checkinPreferences =
//      [[FIRInstanceID instanceID] cachedCheckinPreferences];
//  if ([checkinPreferences hasValidCheckinInfo]) {
//    self.checkinPreferences = checkinPreferences;
//  }
//  return [self.checkinPreferences hasValidCheckinInfo];
  return NO;
}

#pragma mark - API

- (NSString *)deviceAuthID {
//  return self.checkinPreferences.deviceID;
  return @"TODO";
}

- (NSString *)secretToken {
//  return self.checkinPreferences.secretToken;
    return @"TODO";
}

- (NSString *)versionInfo {
  return @"TODO";
//  return self.checkinPreferences.versionInfo;
}

- (int64_t)lastCheckinTimestampMillis {
 // return self.checkinPreferences.lastCheckinTimestampMillis;
    return 0; //TODO
}

- (NSString *)digest {
//  return self.checkinPreferences.digest;
    return @"TODO";
}

- (BOOL)hasValidCheckinInfo {
//  return self.checkinPreferences.hasValidCheckinInfo;
  return NO; //@"TODO";
}

@end
