/*
 * Copyright 2020 Google
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

#import <GoogleDataTransport/GDTCORLifecycle.h>
#import <GoogleDataTransport/GDTCORStorageEventSelector.h>
#import <GoogleDataTransport/GDTCORTargets.h>

@class GDTCOREvent;
@class GDTCORClock;

NS_ASSUME_NONNULL_BEGIN

/** Defines an iterator API for processing or fetching events. */
@protocol GDTCORStorageEventIterator <NSObject>

@required

/** Initializes an iterator instance with the given target and queue.
 *
 * @param target The target for which the events are stored.
 * @param queue The queue on which the iterator should run.
 * @return An iterator instance.
 */
- (instancetype)initWithTarget:(GDTCORTarget)target queue:(dispatch_queue_t)queue;

/** Returns the next event or nil if there are no more events to iterate over.
 *
 * @return A GDTCOREvent instance or nil if the iterator has iterated through all the events.
 */
- (nullable GDTCOREvent *)nextEvent;

@end

/** Defines the interface a storage subsystem is expected to implement. */
@protocol GDTCORStorageProtocol <NSObject, GDTCORLifecycleProtocol>

@required

/** Stores an event and calls onComplete with a non-nil error if anything went wrong.
 *
 * @param event The event to store
 * @param completion The completion block to call after an attempt to store the event has been made.
 */
- (void)storeEvent:(GDTCOREvent *)event
        onComplete:(void (^_Nullable)(BOOL wasWritten, NSError *_Nullable error))completion;

/** Removes the events from storage. */
- (void)removeEvents:(NSSet<NSNumber *> *)eventIDs;

/** Persists the given data with the given key.
 *
 * @param data The data to store.
 * @param key The unique key to store it to.
 * @param onComplete An block to be run when storage of the data is complete.
 */
- (void)storeLibraryData:(NSData *)data
                  forKey:(NSString *)key
              onComplete:(nullable void (^)(NSError *_Nullable error))onComplete;

/** Retrieves the stored data for the given key.
 *
 * @param key The key corresponding to the desired data.
 * @param onComplete The callback to invoke with the data once it's retrieved.
 */
- (void)libraryDataForKey:(NSString *)key
               onComplete:(void (^)(NSData *_Nullable data, NSError *_Nullable error))onComplete;

/** Removes data from storage and calls the callback when complete.
 *
 * @param key The key of the data to remove.
 * @param onComplete The callback that will be invoked when removing the data is complete.
 */
- (void)removeLibraryDataForKey:(NSString *)key
                     onComplete:(void (^)(NSError *_Nullable error))onComplete;

/** Returns YES if some events have been stored for the given target, NO otherwise.
 *
 * @return YES if the storage contains events for the given target, NO otherwise.
 */
- (BOOL)hasEventsForTarget:(GDTCORTarget)target;

/** Returns an iterator object that can be used to iterate over events that match the eventSelector.
 *
 * @param eventSelector The event selector to match events with.
 * @return An iterator instance.
 */
- (nullable id<GDTCORStorageEventIterator>)iteratorWithSelector:
    (GDTCORStorageEventSelector *)eventSelector;

/** Removes events from before the given time.
 *
 * @param beforeSnapshot The time at which all events prior should be deleted.
 * @param onComplete The callback that will be invoked when deleting events is complete.
 */
- (void)purgeEventsFromBefore:(GDTCORClock *)beforeSnapshot
                   onComplete:(void (^)(NSError *_Nullable error))onComplete;

/** Calculates and returns the total disk size that this storage consumes.
 *
 * @param onComplete The callback that will be invoked once storage size calculation is complete.
 */
- (void)storageSizeWithCallback:(void (^)(uint64_t storageSize))onComplete;

@end

/** Retrieves the storage instance for the given target.
 *
 * @param target The target.
 * * @return The storage instance registered for the target, or nil if there is none.
 */
FOUNDATION_EXPORT
id<GDTCORStorageProtocol> _Nullable GDTCORStorageInstanceForTarget(GDTCORTarget target);

NS_ASSUME_NONNULL_END
