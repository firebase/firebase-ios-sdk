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
#import "GDTLogStorage.h"
#import "GDTRegistrar_Private.h"

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

- (instancetype)init {
  self = [super init];
  if (self) {
    _coordinationQueue =
        dispatch_queue_create("com.google.GDTUploadCoordinator", DISPATCH_QUEUE_SERIAL);
    _registrar = [GDTRegistrar sharedInstance];
    _logTargetToNextUploadTimes = [[NSMutableDictionary alloc] init];
    _logTargetToInFlightLogSet = [[NSMutableDictionary alloc] init];
    _forcedUploadQueue = [[NSMutableArray alloc] init];
    _timerInterval = 30 * NSEC_PER_SEC;
    _timerLeeway = 5 * NSEC_PER_SEC;
  }
  return self;
}

- (void)forceUploadLogs:(NSSet<NSNumber *> *)logHashes target:(GDTLogTarget)logTarget {
  dispatch_async(_coordinationQueue, ^{
    NSNumber *logTargetNumber = @(logTarget);
    GDTRegistrar *registrar = self->_registrar;
    GDTUploadCoordinatorForceUploadBlock forceUploadBlock = ^{
      GDTAssert(logHashes.count, @"It doesn't make sense to force upload of 0 logs");
      id<GDTLogUploader> uploader = registrar.logTargetToUploader[logTargetNumber];
      NSSet<NSURL *> *logFiles = [self.logStorage logHashesToFiles:logHashes];
      GDTAssert(uploader, @"log target '%@' is missing an implementation", logTargetNumber);
      [uploader uploadLogs:logFiles onComplete:self.onCompleteBlock];
      self->_logTargetToInFlightLogSet[logTargetNumber] = logHashes;
    };

    // Enqueue the force upload block if there's an in-flight upload for that target already.
    if (self->_logTargetToInFlightLogSet[logTargetNumber]) {
      [self->_forcedUploadQueue insertObject:forceUploadBlock atIndex:0];
    } else {
      forceUploadBlock();
    }
  });
}

#pragma mark - Property overrides

// GDTLogStorage and GDTUploadCoordinator +sharedInstance methods call each other, so this breaks
// the loop.
- (GDTLogStorage *)logStorage {
  if (!_logStorage) {
    _logStorage = [GDTLogStorage sharedInstance];
  }
  return _logStorage;
}

// This should always be called in a thread-safe manner.
- (GDTUploaderCompletionBlock)onCompleteBlock {
  __weak GDTUploadCoordinator *weakSelf = self;
  static GDTUploaderCompletionBlock onCompleteBlock;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    onCompleteBlock = ^(GDTLogTarget target, GDTClock *nextUploadAttemptUTC, NSError *error) {
      GDTUploadCoordinator *strongSelf = weakSelf;
      if (strongSelf) {
        dispatch_async(strongSelf.coordinationQueue, ^{
          NSNumber *logTarget = @(target);
          if (error) {
            GDTLogWarning(GDTMCWUploadFailed, @"Error during upload: %@", error);
            [strongSelf->_logTargetToInFlightLogSet removeObjectForKey:logTarget];
            return;
          }
          strongSelf->_logTargetToNextUploadTimes[logTarget] = nextUploadAttemptUTC;
          NSSet<NSNumber *> *logHashSet =
              [strongSelf->_logTargetToInFlightLogSet objectForKey:logTarget];
          GDTAssert(logHashSet, @"There should be an in-flight log set to remove.");
          [strongSelf.logStorage removeLogs:logHashSet logTarget:logTarget];
          [strongSelf->_logTargetToInFlightLogSet removeObjectForKey:logTarget];
          if (strongSelf->_forcedUploadQueue.count) {
            GDTUploadCoordinatorForceUploadBlock queuedBlock =
                [strongSelf->_forcedUploadQueue lastObject];
            if (queuedBlock) {
              queuedBlock();
            }
            [strongSelf->_forcedUploadQueue removeLastObject];
          }
        });
      }
    };
  });
  return onCompleteBlock;
}

#pragma mark - Private helper methods

/** Starts a timer that checks whether or not logs can be uploaded at regular intervals. It will
 * check the next-upload clocks of all log targets to determine if an upload attempt can be made.
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
      [self checkPrioritizersAndUploadLogs];
    });
    dispatch_resume(strongSelf->_timer);
  });
}

/** Checks the next upload time for each log target and makes a determination on whether to upload
 * logs for that target or not. If so, queries the prioritizers
 */
- (void)checkPrioritizersAndUploadLogs {
  __weak GDTUploadCoordinator *weakSelf = self;
  dispatch_async(_coordinationQueue, ^{
    static int count = 0;
    count++;
    GDTUploadCoordinator *strongSelf = weakSelf;
    if (strongSelf) {
      NSArray<NSNumber *> *logTargetsReadyForUpload = [self logTargetsReadyForUpload];
      for (NSNumber *logTarget in logTargetsReadyForUpload) {
        id<GDTLogPrioritizer> prioritizer =
            strongSelf->_registrar.logTargetToPrioritizer[logTarget];
        id<GDTLogUploader> uploader = strongSelf->_registrar.logTargetToUploader[logTarget];
        GDTAssert(prioritizer && uploader, @"log target '%@' is missing an implementation",
                  logTarget);
        GDTUploadConditions conds = [self uploadConditions];
        NSSet<NSNumber *> *logHashesToUpload =
            [[prioritizer logsToUploadGivenConditions:conds] copy];
        if (logHashesToUpload && logHashesToUpload.count > 0) {
          NSAssert(logHashesToUpload.count > 0, @"");
          NSSet<NSURL *> *logFilesToUpload =
              [strongSelf.logStorage logHashesToFiles:logHashesToUpload];
          NSAssert(logFilesToUpload.count == logHashesToUpload.count,
                   @"There should be the same number of files to logs");
          strongSelf->_logTargetToInFlightLogSet[logTarget] = logHashesToUpload;
          [uploader uploadLogs:logFilesToUpload onComplete:self.onCompleteBlock];
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

/** Checks the next upload time for each log target and returns an array of log targets that are
 * able to make an upload attempt.
 *
 * @return An array of log targets wrapped in NSNumbers that are ready for upload attempts.
 */
- (NSArray<NSNumber *> *)logTargetsReadyForUpload {
  NSMutableArray *logTargetsReadyForUpload = [[NSMutableArray alloc] init];
  GDTClock *currentTime = [GDTClock snapshot];
  for (NSNumber *logTarget in self.registrar.logTargetToPrioritizer) {
    // Log targets in flight are not ready.
    if (_logTargetToInFlightLogSet[logTarget]) {
      continue;
    }
    GDTClock *nextUploadTime = _logTargetToNextUploadTimes[logTarget];

    // If no next upload time was specified or if the currentTime > nextUpload time, mark as ready.
    if (!nextUploadTime || [currentTime isAfter:nextUploadTime]) {
      [logTargetsReadyForUpload addObject:logTarget];
    }
  }
  return logTargetsReadyForUpload;
}

@end
