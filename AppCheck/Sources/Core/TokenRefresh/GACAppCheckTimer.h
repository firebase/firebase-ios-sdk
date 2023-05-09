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

NS_ASSUME_NONNULL_BEGIN

@protocol GACAppCheckTimerProtocol <NSObject>

- (void)invalidate;

@end

typedef id<GACAppCheckTimerProtocol> _Nullable (^GACTimerProvider)(NSDate *fireDate,
                                                                   dispatch_queue_t queue,
                                                                   dispatch_block_t handler);

@interface GACAppCheckTimer : NSObject <GACAppCheckTimerProtocol>

+ (GACTimerProvider)timerProvider;

- (nullable instancetype)initWithFireDate:(NSDate *)date
                            dispatchQueue:(dispatch_queue_t)dispatchQueue
                                    block:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
