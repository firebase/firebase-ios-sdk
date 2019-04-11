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

#import <GoogleDataTransport/GDTLifecycle.h>
#import <GoogleDataTransport/GDTUploadPackage.h>

@class GDTStoredEvent;

NS_ASSUME_NONNULL_BEGIN

/** Options that define a set of upload conditions. This is used to help minimize end user data
 * consumption impact.
 */
typedef NS_OPTIONS(NSInteger, GDTUploadConditions) {

  /** An upload would likely use mobile data. */
  GDTUploadConditionMobileData,

  /** An upload would likely use wifi data. */
  GDTUploadConditionWifiData,

  /** A high priority event has occurred. */
  GDTUploadConditionHighPriority,
};

/** This protocol defines the common interface of event prioritization. Prioritizers are
 * stateful objects that prioritize events upon insertion into storage and remain prepared to return
 * a set of filenames to the storage system.
 */
@protocol GDTPrioritizer <NSObject, GDTLifecycleProtocol>

@required

/** Accepts an event and uses the event metadata to make choices on how to prioritize the event.
 * This method exists as a way to help prioritize which events should be sent, which is dependent on
 * the request proto structure of your backend.
 *
 * @param event The event to prioritize.
 */
- (void)prioritizeEvent:(GDTStoredEvent *)event;

/** Unprioritizes a set of events. This method is called after all the events in the set have been
 * removed from storage and from disk. It's passed as a set so that instead of having N blocks
 * dispatched to a queue, it can be a single block--this prevents possible race conditions in which
 * the storage system has removed the events, but the prioritizers haven't unprioritized the events
 * because it was being done one at a time.
 *
 * @param events The set of events to unprioritize.
 */
- (void)unprioritizeEvents:(NSSet<GDTStoredEvent *> *)events;

/** Returns a set of events to upload given a set of conditions.
 *
 * @param conditions A bit mask specifying the current upload conditions.
 * @return An object to be used by the uploader to determine file URLs to upload with respect to the
 * current conditions.
 */
- (GDTUploadPackage *)uploadPackageWithConditions:(GDTUploadConditions)conditions;

@end

NS_ASSUME_NONNULL_END
