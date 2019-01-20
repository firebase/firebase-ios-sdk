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

#import "GDLUploadCoordinator.h"

@class GDLClock;
@class GDLLogStorage;

/** A convenience typedef to define the a block containing a force upload attempt. */
typedef void (^GDLUploadCoordinatorForceUploadBlock)(void);

NS_ASSUME_NONNULL_BEGIN

@interface GDLUploadCoordinator ()

/** The queue on which all upload coordination will occur. Also used by a dispatch timer. */
@property(nonatomic, readonly) dispatch_queue_t coordinationQueue;

/** The completion block to run after an uploader completes. */
@property(nonatomic, readonly) GDLUploaderCompletionBlock onCompleteBlock;

/** A map of log targets to their desired next upload time, if they have one. */
@property(nonatomic, readonly)
    NSMutableDictionary<NSNumber *, GDLClock *> *logTargetToNextUploadTimes;

/** A map of log targets to a set of log hashes that has been handed off to the uploader. */
@property(nonatomic, readonly)
    NSMutableDictionary<NSNumber *, NSSet<NSNumber *> *> *logTargetToInFlightLogSet;

/** A queue of forced uploads. Only populated if the log target already had in-flight logs. */
@property(nonatomic, readonly)
    NSMutableArray<GDLUploadCoordinatorForceUploadBlock> *forcedUploadQueue;

/** A timer that will causes regular checks for logs to upload. */
@property(nonatomic, readonly) dispatch_source_t timer;

/** The interval the timer will fire. */
@property(nonatomic, readonly) uint64_t timerInterval;

/** Some leeway given to libdispatch for the timer interval event. */
@property(nonatomic, readonly) uint64_t timerLeeway;

/** The log storage object the coordinator will use. Generally used for testing. */
@property(nonatomic) GDLLogStorage *logStorage;

/** The registrar object the coordinator will use. Generally used for testing. */
@property(nonatomic) GDLRegistrar *registrar;

/** Starts the upload timer. */
- (void)startTimer;

@end

NS_ASSUME_NONNULL_END
