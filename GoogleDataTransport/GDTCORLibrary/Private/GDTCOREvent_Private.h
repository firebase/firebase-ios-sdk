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

#import "GoogleDataTransport/GDTCORLibrary/Public/GDTCOREvent.h"

#import "GoogleDataTransport/GDTCORLibrary/Public/GDTCORClock.h"

NS_ASSUME_NONNULL_BEGIN

@interface GDTCOREvent ()

/** The unique ID of the event. This property is for testing only. */
@property(nonatomic, readwrite) NSNumber *eventID;

/** Generates incrementing event IDs, stored in a file in the app's cache.
 *
 * @param onComplete The block to run once the next event ID has been generated.
 */
+ (void)nextEventIDForTarget:(GDTCORTarget)target
                  onComplete:(void (^)(NSNumber *_Nullable eventID))onComplete;

@end

NS_ASSUME_NONNULL_END
