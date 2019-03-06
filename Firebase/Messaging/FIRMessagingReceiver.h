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

#import "FIRMessagingDataMessageManager.h"
#import "FIRMessaging.h"

NS_ASSUME_NONNULL_BEGIN

@class FIRMessagingReceiver;
@class GULUserDefaults;
@protocol FIRMessagingReceiverDelegate <NSObject>

- (void)receiver:(FIRMessagingReceiver *)receiver
      receivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage;

@end

@interface FIRMessagingReceiver : NSObject <FIRMessagingDataMessageManagerDelegate>

/// Default initializer for creating the messaging receiver.
- (instancetype)initWithUserDefaults:(GULUserDefaults *)defaults NS_DESIGNATED_INITIALIZER;

/// Use `initWithUserDefaults:` instead.
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, weak, nullable) id<FIRMessagingReceiverDelegate> delegate;
/// Whether to use direct channel for direct channel message callback handler in all iOS versions.
@property(nonatomic, assign) BOOL useDirectChannel;

@end

NS_ASSUME_NONNULL_END
