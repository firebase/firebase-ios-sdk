/*
 * Copyright 2021 Google LLC
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

#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTimer.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^FIRFakeTimerCreateHandler)(NSDate *fireDate);

@interface FIRFakeTimer : NSObject <FIRAppCheckTimerProtocol>

- (FIRTimerProvider)fakeTimerProvider;

/// `createHandler` is called each time the timer provider returned by `fakeTimerProvider` is asked
/// to create a timer.
@property(nonatomic, copy, nullable) FIRFakeTimerCreateHandler createHandler;

@property(nonatomic, copy, nullable) dispatch_block_t invalidationHandler;

/// The timer handler passed in the timer provider returned by `fakeTimerProvider` method.
@property(nonatomic, copy, nullable) dispatch_block_t handler;

@end

NS_ASSUME_NONNULL_END
