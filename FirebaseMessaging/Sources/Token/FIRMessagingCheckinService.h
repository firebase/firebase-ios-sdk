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

#import <Foundation/Foundation.h>

#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"

NS_ASSUME_NONNULL_BEGIN

// keys in Checkin preferences
FOUNDATION_EXPORT NSString *const kFIRMessagingDeviceAuthIdKey;
FOUNDATION_EXPORT NSString *const kFIRMessagingSecretTokenKey;
FOUNDATION_EXPORT NSString *const kFIRMessagingDigestStringKey;
FOUNDATION_EXPORT NSString *const kFIRMessagingLastCheckinTimeKey;
FOUNDATION_EXPORT NSString *const kFIRMessagingVersionInfoStringKey;
FOUNDATION_EXPORT NSString *const kFIRMessagingGServicesDictionaryKey;
FOUNDATION_EXPORT NSString *const kFIRMessagingDeviceDataVersionKey;

@class FIRMessagingCheckinPreferences;

/**
 *  Register the device with Checkin Service and get back the `authID`, `secret
 *  token` etc. for the client. Checkin results are cached in the
 *  `FIRMessagingCache` and periodically refreshed to prevent them from being stale.
 *  Each client needs to register with checkin before registering with InstanceID.
 */
@interface FIRMessagingCheckinService : NSObject

/**
 *  Execute a device checkin request to obtain an deviceID, secret token,
 *  gService data.
 *
 *  @param existingCheckin An existing checkin preference object, if available.
 *  @param completion Completion handler called on success or failure of device checkin.
 */
- (void)checkinWithExistingCheckin:(nullable FIRMessagingCheckinPreferences *)existingCheckin
                        completion:
                            (void (^)(FIRMessagingCheckinPreferences *_Nullable checkinPreferences,
                                      NSError *_Nullable error))completion;

/**
 *  This would stop any request that the service made to the checkin backend and also
 *  release any callback handlers that it holds.
 */
- (void)stopFetching;

@end

NS_ASSUME_NONNULL_END
