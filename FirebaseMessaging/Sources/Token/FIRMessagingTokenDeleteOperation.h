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

#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRMessagingTokenDeleteOperation : FIRMessagingTokenOperation

- (instancetype)initWithAuthorizedEntity:(nullable NSString *)authorizedEntity
                                   scope:(nullable NSString *)scope
                      checkinPreferences:(FIRMessagingCheckinPreferences *)checkinPreferences
                              instanceID:(nullable NSString *)instanceID
                                  action:(FIRMessagingTokenAction)action
                         heartbeatLogger:(id<FIRHeartbeatLoggerProtocol>)heartbeatLogger;

@end

NS_ASSUME_NONNULL_END
