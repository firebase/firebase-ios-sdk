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

#import <GoogleDataTransport/GDTCORLifecycle.h>
#import <GoogleDataTransport/GDTCORStorageEventSelector.h>
#import <GoogleDataTransport/GDTCORStorageProtocol.h>

@class GDTCOREvent;
@class GDTCORUploadCoordinator;

NS_ASSUME_NONNULL_BEGIN

/** The key of the event data path if a path dictionary is returned. */
FOUNDATION_EXPORT NSString *const gGDTCORFlatFileStorageEventDataPathKey;

/** The key of the event's mapping ID path if a path dictionary is returned. */
FOUNDATION_EXPORT NSString *const gGDTCORFlatFileStorageMappingIDPathKey;

/** The key of the event's qos tier path if a path dictionary is returned. */
FOUNDATION_EXPORT NSString *const gGDTCORFlatFileStorageQoSTierPathKey;

/** Manages the storage of events. This class is thread-safe. */
@interface GDTCORFlatFileStorage
    : NSObject <NSSecureCoding, GDTCORStorageProtocol, GDTCORLifecycleProtocol>

/** The queue on which all storage work will occur. */
@property(nonatomic) dispatch_queue_t storageQueue;

/** A map of targets to a set of stored events. */
@property(nonatomic)
    NSMutableDictionary<NSNumber *, NSMutableSet<GDTCOREvent *> *> *targetToEventSet;

/** All the events that have been stored. */
@property(readonly, nonatomic) NSMutableDictionary<NSNumber *, GDTCOREvent *> *storedEvents;

/** The upload coordinator instance used by this storage instance. */
@property(nonatomic) GDTCORUploadCoordinator *uploadCoordinator;

/** Creates and/or returns the storage singleton.
 *
 * @return The storage singleton.
 */
+ (instancetype)sharedInstance;

/** Returns the path to the keyed archive of the singleton. This is where the singleton is saved
 * to disk during certain app lifecycle events.
 *
 * @return File path to serialized singleton.
 */
+ (NSString *)archivePath;

/** Returns storage paths for the given event, though the paths may not exist.
 *
 * @note The keys of this dictionary are declared in this header.
 * @param event The event to map to storage paths.
 */
+ (NSDictionary<NSString *, NSString *> *)pathsForEvent:(GDTCOREvent *)event;

/** Returns a storage path to events for the given target, qosTier, and mapping ID. The path may not
 * exist.
 *
 * @param target The target, which is necessary to be given a path.
 * @param qosTier An optional parameter to get a more specific path.
 * @param mappingID An optional parameter to get a more specific path.
 * @return The path representing the combination of the given parameters.
 */
+ (NSString *)pathForTarget:(GDTCORTarget)target
                    qosTier:(nullable NSNumber *)qosTier
                  mappingID:(nullable NSString *)mappingID;

/** Returns a list of paths that will contain events for the given event selector.
 *
 * @param eventSelector The event selector to process.
 * @return A list of paths that exist and could contain events.
 */
+ (nullable NSArray<NSString *> *)searchPathsWithEventSelector:
    (GDTCORStorageEventSelector *)eventSelector;

@end

NS_ASSUME_NONNULL_END
