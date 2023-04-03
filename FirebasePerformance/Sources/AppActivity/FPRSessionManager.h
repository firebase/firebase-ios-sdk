// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

#import "FirebasePerformance/Sources/AppActivity/FPRSessionDetails.h"

/* Notification name when the session Id gets updated. */
FOUNDATION_EXTERN NSString *_Nonnull const kFPRSessionIdUpdatedNotification;

/* Notification name when the session Id gets updated. */
FOUNDATION_EXTERN NSString *_Nonnull const kFPRSessionIdNotificationKey;

/** This class manages the current active sessionId of the application and provides mechanism for
 *  propagating the session Id.
 */
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
@interface FPRSessionManager : NSObject

/** The current active session managed by the session manager. */
@property(atomic, readonly, nonnull) FPRSessionDetails *sessionDetails;

/**
 * The notification center managed by the session manager. All the notifications by the session
 * manager will get broadcasted on this notification center.
 */
@property(nonatomic, readonly, nonnull) NSNotificationCenter *sessionNotificationCenter;

/**
 * The shared instance of Session Manager.
 *
 * @return The singleton instance.
 */
+ (nonnull FPRSessionManager *)sharedInstance;

- (nullable instancetype)init NS_UNAVAILABLE;

- (void)updateSessionId:(nonnull NSString *)sessionIdString;

// Collects all the enabled gauge metrics once.
- (void)collectAllGaugesOnce;

@end
