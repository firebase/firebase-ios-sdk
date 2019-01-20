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

#import "GDLUploadCoordinator.h"
#import "GDLUploadCoordinator_Private.h"

#import "GDLAssert.h"
#import "GDLClock.h"
#import "GDLConsoleLogger.h"
#import "GDLLogStorage.h"
#import "GDLRegistrar_Private.h"

@implementation GDLUploadCoordinator

+ (instancetype)sharedInstance {
  static GDLUploadCoordinator *sharedUploader;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedUploader = [[GDLUploadCoordinator alloc] init];
    [sharedUploader startTimer];
  });
  return sharedUploader;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _coordinationQueue =
        dispatch_queue_create("com.google.GDLUploadCoordinator", DISPATCH_QUEUE_SERIAL);
    _registrar = [GDLRegistrar sharedInstance];
    _logTargetToNextUploadTimes = [[NSMutableDictionary alloc] init];
    _logTargetToInFlightLogSet = [[NSMutableDictionary alloc] init];
    _forcedUploadQueue = [[NSMutableArray alloc] init];
    _timerInterval = 30 * NSEC_PER_SEC;
    _timerLeeway = 5 * NSEC_PER_SEC;
  }
  return self;
}

- (void)forceUploadLogs:(NSSet<NSNumber *> *)logHashes target:(GDLLogTarget)logTarget {
  dispatch_async(_coordinationQueue, ^{
    NSNumber *logTargetNumber = @(logTarget);
    GDLRegistrar *registrar = self->_registrar;
    GDLUploadCoordinatorForceUploadBlock forceUploadBlock = ^{
      GDLAssert(logHashes.count, @"It doesn't make sense to force upload of 0 logs");
      id<GDLLogUploader> uploader = registrar.logTargetToUploader[logTargetNumber];
      NSSet<NSURL *> *logFiles = [self.logStorage logHashesToFiles:logHashes];
      GDLAssert(uploader, @"log target '%@' is missing an implementation", logTargetNumber);
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

// GDLLogStorage and GDLUploadCoordinator +sharedInstance methods call each other, so this breaks
// the loop.
- (GDLLogStorage *)logStorage {
  if (!_logStorage) {
    _logStorage = [GDLLogStorage sharedInstance];
  }
  return _logStorage;
}

// This should always be called in a thread-safe manner.
- (GDLUploaderCompletionBlock)onCompleteBlock {
  __weak GDLUploadCoordinator *weakSelf = self;
  static GDLUploaderCompletionBlock onCompleteBlock;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    onCompleteBlock = ^(GDLLogTarget target, GDLClock *nextUploadAttemptUTC, NSError *error) {
      GDLUploadCoordinator *strongSelf = weakSelf;
      if (strongSelf) {
        NSNumber *logTarget = @(target);
        if (error) {
          GDLLogWarning(GDLMCWUploadFailed, @"Error during upload: %@", error);
          [strongSelf->_logTargetToInFlightLogSet removeObjectForKey:logTarget];
          return;
        }
        strongSelf->_logTargetToNextUploadTimes[logTarget] = nextUploadAttemptUTC;
        NSSet<NSNumber *> *logHashSet =
            [strongSelf->_logTargetToInFlightLogSet objectForKey:logTarget];
        [strongSelf.logStorage removeLogs:logHashSet logTarget:logTarget];
        [strongSelf->_logTargetToInFlightLogSet removeObjectForKey:logTarget];
        if (strongSelf->_forcedUploadQueue.count) {
          GDLUploadCoordinatorForceUploadBlock queuedBlock =
              [strongSelf->_forcedUploadQueue lastObject];
          if (queuedBlock) {
            queuedBlock();
          }
          [strongSelf->_forcedUploadQueue removeLastObject];
        }
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
  __weak GDLUploadCoordinator *weakSelf = self;
  dispatch_sync(_coordinationQueue, ^{
    GDLUploadCoordinator *strongSelf = weakSelf;
    GDLAssert(strongSelf, @"self must be real to start a timer.");
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
  __weak GDLUploadCoordinator *weakSelf = self;
  dispatch_async(_coordinationQueue, ^{
    GDLUploadCoordinator *strongSelf = weakSelf;
    if (strongSelf) {
      NSArray<NSNumber *> *logTargetsReadyForUpload = [self logTargetsReadyForUpload];
      for (NSNumber *logTarget in logTargetsReadyForUpload) {
        id<GDLLogPrioritizer> prioritizer =
            strongSelf->_registrar.logTargetToPrioritizer[logTarget];
        id<GDLLogUploader> uploader = strongSelf->_registrar.logTargetToUploader[logTarget];
        GDLAssert(prioritizer && uploader, @"log target '%@' is missing an implementation",
                  logTarget);
        NSSet<NSNumber *> *logHashesToUpload = [prioritizer logsForNextUpload];
        if (logHashesToUpload && logHashesToUpload.count > 0) {
          NSSet<NSURL *> *logFilesToUpload =
              [strongSelf.logStorage logHashesToFiles:logHashesToUpload];
          [uploader uploadLogs:logFilesToUpload onComplete:self.onCompleteBlock];
          strongSelf->_logTargetToInFlightLogSet[logTarget] = logHashesToUpload;
        }
      }
    }
  });
}

/** Checks the next upload time for each log target and returns an array of log targets that are
 * able to make an upload attempt.
 *
 * @return An array of log targets wrapped in NSNumbers that are ready for upload attempts.
 */
- (NSArray<NSNumber *> *)logTargetsReadyForUpload {
  NSMutableArray *logTargetsReadyForUpload = [[NSMutableArray alloc] init];
  GDLClock *currentTime = [GDLClock snapshot];
  for (NSNumber *logTarget in self.registrar.logTargetToPrioritizer) {
    GDLClock *nextUploadTime = _logTargetToNextUploadTimes[logTarget];

    // If no next upload time was specified or if the currentTime > nextUpload time, mark as ready.
    if (!nextUploadTime || [currentTime isAfter:nextUploadTime]) {
      [logTargetsReadyForUpload addObject:logTarget];
    }
  }
  return logTargetsReadyForUpload;
}

@end
