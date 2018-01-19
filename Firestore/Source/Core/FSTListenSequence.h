/*
 * Copyright 2018 Google
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

#import "FSTTypes.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * FSTListenSequence is a monotonic sequence. It is initialized with a minimum value to
 * exceed. All subsequent calls to next will return increasing values.
 */
@interface FSTListenSequence : NSObject

- (instancetype)initStartingAfter:(FSTListenSequenceNumber)after NS_DESIGNATED_INITIALIZER;

- (id)init NS_UNAVAILABLE;

- (FSTListenSequenceNumber)next;

@end

NS_ASSUME_NONNULL_END