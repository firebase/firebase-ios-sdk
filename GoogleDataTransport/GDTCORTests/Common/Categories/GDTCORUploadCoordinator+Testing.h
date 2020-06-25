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

#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORUploadCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

@interface GDTCORUploadCoordinator (Testing)

/** Resets the properties of the singleton, but does not reallocate a new singleton. */
- (void)reset;

/** The time interval, in nanoseconds, that the time should be called on. */
@property(nonatomic, readwrite) uint64_t timerInterval;

/** The time interval, in nanoseconds, that should be given as leeway to the timer callbacks. */
@property(nonatomic, readwrite) uint64_t timerLeeway;

@end

NS_ASSUME_NONNULL_END
