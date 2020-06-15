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

/** Manages the storage of events. This class is thread-safe.
 *
 * Event files will be stored as follows:
 * <app cache>/google-sdk-events/<classname>/gdt_event_data/<target>/<eventID>.<qosTier>.<mappingID>
 *
 * Library data will be stored as follows:
 *   <app cache>/gdt_library_data/<key of library data>
 */
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

/** Returns the base directory under which all events will be stored.
 *
 * @return The base directory under which all events will be stored.
 */
+ (NSString *)eventDataStoragePath;

/** Returns the base directory under which all library data will be stored.
 *
 * @return The base directory under which all library data will be stored.
 */
+ (NSString *)libraryDataStoragePath;

/** Returns the base directory under which all batch data will be stored.
 *
 * @return The base directory under which all batch data will be stored.
 */
+ (NSString *)batchDataStoragePath;

/** */
+ (NSString *)batchPathForTarget:(GDTCORTarget)target batchID:(NSNumber *)batchID;

/** Returns a constructed storage path based on the given values. This path may not exist.
 *
 * @param target The target, which is necessary to be given a path.
 * @param eventID The eventID.
 * @param qosTier The qosTier.
 * @param mappingID The mappingID.
 * @return The path representing the combination of the given parameters.
 */
+ (NSString *)pathForTarget:(GDTCORTarget)target
                    eventID:(NSNumber *)eventID
                    qosTier:(NSNumber *)qosTier
                  mappingID:(NSString *)mappingID;

/** Returns extant paths that match all of the given parameters.
 *
 * @param eventIDs The list of eventIDs to look for, or nil for any.
 * @param qosTiers The list of qosTiers to look for, or nil for any.
 * @param mappingIDs The list of mappingIDs to look for, or nil for any.
 * @param onComplete The completion to call once the paths have been discovered.
 */
- (void)pathsForTarget:(GDTCORTarget)target
              eventIDs:(nullable NSSet<NSNumber *> *)eventIDs
              qosTiers:(nullable NSSet<NSNumber *> *)qosTiers
            mappingIDs:(nullable NSSet<NSString *> *)mappingIDs
            onComplete:(void (^)(NSSet<NSString *> *paths))onComplete;

/** Fetches the current batchID counter value from library storage, increments it, and sets the new
 * value. Returns nil if a batchID was not able to be created for some reason.
 *
 * @return The current value of the batchID counter.
 */
- (nullable NSNumber *)nextBatchID;

@end

NS_ASSUME_NONNULL_END
