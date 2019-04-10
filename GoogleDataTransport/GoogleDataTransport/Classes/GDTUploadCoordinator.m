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

#import "GDTUploadCoordinator.h"
#import "GDTUploadCoordinator_Private.h"

#import "GDTAssert.h"
#import "GDTClock.h"
#import "GDTConsoleLogger.h"
#import "GDTRegistrar_Private.h"
#import "GDTStorage.h"
#import "GDTUploadPackage_Private.h"

@implementation GDTUploadCoordinator

+ (instancetype)sharedInstance {
  static GDTUploadCoordinator *sharedUploader;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedUploader = [[GDTUploadCoordinator alloc] init];
    [sharedUploader startTimer];
  });
  return sharedUploader;
}

+ (NSString *)archivePath {
  static NSString *archivePath;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSString *cachePath =
        NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    NSString *storagePath = [NSString stringWithFormat:@"%@/google-sdks-events", cachePath];
    archivePath = [storagePath stringByAppendingPathComponent:@"GDTUploadCoordinator"];
  });
  return archivePath;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _coordinationQueue =
        dispatch_queue_create("com.google.GDTUploadCoordinator", DISPATCH_QUEUE_SERIAL);
    _registrar = [GDTRegistrar sharedInstance];
    _targetToNextUploadTimes = [[NSMutableDictionary alloc] init];
    _targetToInFlightEventSet = [[NSMutableDictionary alloc] init];
    _forcedUploadQueue = [[NSMutableArray alloc] init];
    _timerInterval = 30 * NSEC_PER_SEC;
    _timerLeeway = 5 * NSEC_PER_SEC;
  }
  return self;
}

- (void)forceUploadForTarget:(GDTTarget)target {
  dispatch_async(_coordinationQueue, ^{
    GDTLogWarning(GDTMCWForcedUpload, @"%@", @"A high priority event has caused an upload.");
    NSNumber *targetNumber = @(target);
    GDTUploadCoordinatorForceUploadBlock forceUploadBlock = ^{
      id<GDTPrioritizer> prioritizer = self->_registrar.targetToPrioritizer[targetNumber];
      id<GDTUploader> uploader = self->_registrar.targetToUploader[targetNumber];
      GDTAssert(prioritizer && uploader, @"Target '%@' is missing an implementation", targetNumber);
      GDTUploadConditions conds = [self uploadConditions];
      conds |= GDTUploadConditionHighPriority;
      GDTUploadPackage *package = [[prioritizer uploadPackageWithConditions:conds] copy];
      package.storage = self.storage;
      NSAssert(package.events && package.events.count,
               @"A high priority event should produce events to upload.");
      self->_targetToInFlightEventSet[targetNumber] = package.events;
      [uploader uploadPackage:package onComplete:self.onCompleteBlock];
      [self->_forcedUploadQueue removeLastObject];
    };

    // Enqueue the force upload block if there's an in-flight upload for that target already.
    if (self->_targetToInFlightEventSet[targetNumber]) {
      [self->_forcedUploadQueue insertObject:forceUploadBlock atIndex:0];
    } else {
      forceUploadBlock();
    }
  });
}

#pragma mark - Property overrides

// GDTStorage and GDTUploadCoordinator +sharedInstance methods call each other, so this breaks
// the loop.
- (GDTStorage *)storage {
  if (!_storage) {
    _storage = [GDTStorage sharedInstance];
  }
  return _storage;
}

// This should always be called in a thread-safe manner.
- (GDTUploaderCompletionBlock)onCompleteBlock {
  __weak GDTUploadCoordinator *weakSelf = self;
  static GDTUploaderCompletionBlock onCompleteBlock;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    onCompleteBlock = ^(GDTTarget target, GDTClock *nextUploadAttemptUTC, NSError *error) {
      GDTUploadCoordinator *strongSelf = weakSelf;
      if (strongSelf) {
        dispatch_async(strongSelf.coordinationQueue, ^{
          NSNumber *targetNumber = @(target);
          if (error) {
            GDTLogWarning(GDTMCWUploadFailed, @"Error during upload: %@", error);
            [strongSelf->_targetToInFlightEventSet removeObjectForKey:targetNumber];
            return;
          }
          strongSelf->_targetToNextUploadTimes[targetNumber] = nextUploadAttemptUTC;
          NSSet<GDTStoredEvent *> *events =
              [strongSelf->_targetToInFlightEventSet objectForKey:targetNumber];
          GDTAssert(events, @"There should be an in-flight event set to remove.");
          [strongSelf.storage removeEvents:events];
          [strongSelf->_targetToInFlightEventSet removeObjectForKey:targetNumber];
          if (strongSelf->_forcedUploadQueue.count) {
            GDTUploadCoordinatorForceUploadBlock queuedBlock =
                [strongSelf->_forcedUploadQueue lastObject];
            if (queuedBlock) {
              dispatch_async(strongSelf->_coordinationQueue, ^{
                queuedBlock();
              });
            }
          }
        });
      }
    };
  });
  return onCompleteBlock;
}

#pragma mark - Private helper methods

/** Starts a timer that checks whether or not events can be uploaded at regular intervals. It will
 * check the next-upload clocks of all targets to determine if an upload attempt can be made.
 */
- (void)startTimer {
  __weak GDTUploadCoordinator *weakSelf = self;
  dispatch_sync(_coordinationQueue, ^{
    GDTUploadCoordinator *strongSelf = weakSelf;
    GDTAssert(strongSelf, @"self must be real to start a timer.");
    strongSelf->_timer =
        dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, strongSelf->_coordinationQueue);
    dispatch_source_set_timer(strongSelf->_timer, DISPATCH_TIME_NOW, strongSelf->_timerInterval,
                              strongSelf->_timerLeeway);
    dispatch_source_set_event_handler(strongSelf->_timer, ^{
      [self checkPrioritizersAndUploadEvents];
    });
    dispatch_resume(strongSelf->_timer);
  });
}

/** Stops the currently running timer. */
- (void)stopTimer {
  if (_timer) {
    dispatch_source_cancel(_timer);
  }
}

/** Checks the next upload time for each target and makes a determination on whether to upload
 * events for that target or not. If so, queries the prioritizers
 */
- (void)checkPrioritizersAndUploadEvents {
  __weak GDTUploadCoordinator *weakSelf = self;
  dispatch_async(_coordinationQueue, ^{
    static int count = 0;
    count++;
    GDTUploadCoordinator *strongSelf = weakSelf;
    if (strongSelf) {
      NSArray<NSNumber *> *targetsReadyForUpload = [self targetsReadyForUpload];
      for (NSNumber *target in targetsReadyForUpload) {
        id<GDTPrioritizer> prioritizer = strongSelf->_registrar.targetToPrioritizer[target];
        id<GDTUploader> uploader = strongSelf->_registrar.targetToUploader[target];
        GDTAssert(prioritizer && uploader, @"Target '%@' is missing an implementation", target);
        GDTUploadConditions conds = [self uploadConditions];
        GDTUploadPackage *package = [[prioritizer uploadPackageWithConditions:conds] copy];
        package.storage = strongSelf.storage;
        if (package.events && package.events.count > 0) {
          strongSelf->_targetToInFlightEventSet[target] = package.events;
          [uploader uploadPackage:package onComplete:self.onCompleteBlock];
        }
      }
    }
  });
}

/** */
- (GDTUploadConditions)uploadConditions {
  // TODO: Compute the real upload conditions.
  return GDTUploadConditionMobileData;
}

/** Checks the next upload time for each target and returns an array of targets that are
 * able to make an upload attempt.
 *
 * @return An array of targets wrapped in NSNumbers that are ready for upload attempts.
 */
- (NSArray<NSNumber *> *)targetsReadyForUpload {
  NSMutableArray *targetsReadyForUpload = [[NSMutableArray alloc] init];
  GDTClock *currentTime = [GDTClock snapshot];
  for (NSNumber *target in self.registrar.targetToPrioritizer) {
    // Targets in flight are not ready.
    if (_targetToInFlightEventSet[target]) {
      continue;
    }
    GDTClock *nextUploadTime = _targetToNextUploadTimes[target];

    // If no next upload time was specified or if the currentTime > nextUpload time, mark as ready.
    if (!nextUploadTime || [currentTime isAfter:nextUploadTime]) {
      [targetsReadyForUpload addObject:target];
    }
  }
  return targetsReadyForUpload;
}

@end
