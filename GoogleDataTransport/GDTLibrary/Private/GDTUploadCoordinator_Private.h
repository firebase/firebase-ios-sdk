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

#import "GDTLibrary/Private/GDTUploadCoordinator.h"

#import "GDTLibrary/Private/GDTUploadPackage_Private.h"

@class GDTClock;
@class GDTStorage;

/** A convenience typedef to define the a block containing a force upload attempt. */
typedef void (^GDTUploadCoordinatorForceUploadBlock)(void);

NS_ASSUME_NONNULL_BEGIN

@interface GDTUploadCoordinator () <GDTUploadPackageProtocol>

/** The queue on which all upload coordination will occur. Also used by a dispatch timer. */
@property(nonatomic, readonly) dispatch_queue_t coordinationQueue;

/** A timer that will causes regular checks for events to upload. */
@property(nonatomic, readonly) dispatch_source_t timer;

/** The interval the timer will fire. */
@property(nonatomic, readonly) uint64_t timerInterval;

/** Some leeway given to libdispatch for the timer interval event. */
@property(nonatomic, readonly) uint64_t timerLeeway;

/** The storage object the coordinator will use. Generally used for testing. */
@property(nonatomic) GDTStorage *storage;

/** The registrar object the coordinator will use. Generally used for testing. */
@property(nonatomic) GDTRegistrar *registrar;

/** If YES, completion and other operations will result in serializing the singleton to disk. */
@property(nonatomic, readonly) BOOL runningInBackground;

/** Starts the upload timer. */
- (void)startTimer;

/** Stops the upload timer from running. */
- (void)stopTimer;

@end

NS_ASSUME_NONNULL_END
