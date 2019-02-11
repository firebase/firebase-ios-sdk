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

@class GDTEvent;

NS_ASSUME_NONNULL_BEGIN

/** Options that define a set of upload conditions. This is used to help minimize end user data
 * consumption impact.
 */
typedef NS_OPTIONS(NSInteger, GDTUploadConditions) {

  /** An upload would likely use mobile data. */
  GDTUploadConditionMobileData,

  /** An upload would likely use wifi data. */
  GDTUploadConditionWifiData,
};

/** This protocol defines the common interface of event prioritization. Prioritizers are
 * stateful objects that prioritize events upon insertion into storage and remain prepared to return
 * a set of filenames to the storage system.
 */
@protocol GDTPrioritizer <NSObject>

@required

/** Accepts an event and uses the event metadata to make choices on how to prioritize the event.
 * This method exists as a way to help prioritize which events should be sent, which is dependent on
 * the request proto structure of your backend.
 *
 * @note A couple of things: 1. The event cannot be retained for longer than the execution time of
 * this method. 2. You should retain the event hashes, because those are returned in
 * -eventsForNextUpload.
 *
 * @param event The event to prioritize.
 */
- (void)prioritizeEvent:(GDTEvent *)event;

/** Unprioritizes an event. This method is called when an event has been removed from storage and
 * should no longer be given to an uploader.
 */
- (void)unprioritizeEvent:(NSNumber *)eventHash;

/** Returns a set of events to upload given a set of conditions.
 *
 * @param conditions A bit mask specifying the current upload conditions.
 * @return A set of events to upload with respect to the current conditions.
 */
- (NSSet<NSNumber *> *)eventsToUploadGivenConditions:(GDTUploadConditions)conditions;

@end

NS_ASSUME_NONNULL_END
