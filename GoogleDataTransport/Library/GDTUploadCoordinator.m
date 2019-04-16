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

#import "Library/Private/GDTUploadCoordinator.h"
#import "Library/Private/GDTUploadCoordinator_Private.h"

#import <GoogleDataTransport/GDTClock.h>

#import "Library/Private/GDTAssert.h"
#import "Library/Private/GDTConsoleLogger.h"
#import "Library/Private/GDTReachability.h"
#import "Library/Private/GDTRegistrar_Private.h"
#import "Library/Private/GDTStorage.h"
#import "Library/Private/GDTUploadPackage_Private.h"

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

    if (self->_runningInBackground) {
      [self->_forcedUploadQueue insertObject:forceUploadBlock atIndex:0];
      [NSKeyedArchiver archiveRootObject:self toFile:[GDTUploadCoordinator archivePath]];
      // Enqueue the force upload block if conditions are bad or if there's an in-flight upload for
      // that target already.
    } else if (([self uploadConditions] & GDTUploadConditionNoNetwork) ==
               GDTUploadConditionNoNetwork) {
      [self->_forcedUploadQueue insertObject:forceUploadBlock atIndex:0];
    } else if (self->_targetToInFlightEventSet[targetNumber]) {
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

// This should always be called in a thread-safe manner. When running the background, in theory,
// the uploader's background task should be calling this.
- (GDTUploaderCompletionBlock)onCompleteBlock {
  static GDTUploaderCompletionBlock onCompleteBlock;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    onCompleteBlock = ^(GDTTarget target, GDTClock *nextUploadAttemptUTC, NSError *error) {
      dispatch_async(self->_coordinationQueue, ^{
        NSNumber *targetNumber = @(target);
        if (error) {
          GDTLogWarning(GDTMCWUploadFailed, @"Error during upload: %@", error);
          [self->_targetToInFlightEventSet removeObjectForKey:targetNumber];
          return;
        }
        self->_targetToNextUploadTimes[targetNumber] = nextUploadAttemptUTC;
        NSSet<GDTStoredEvent *> *events =
            [self->_targetToInFlightEventSet objectForKey:targetNumber];
        GDTAssert(events, @"There should be an in-flight event set to remove.");
        [self->_storage removeEvents:events];
        [self->_targetToInFlightEventSet removeObjectForKey:targetNumber];
        if (self->_runningInBackground) {
          [NSKeyedArchiver archiveRootObject:self toFile:[GDTUploadCoordinator archivePath]];
        } else if (self->_forcedUploadQueue.count) {
          GDTUploadCoordinatorForceUploadBlock queuedBlock = [self->_forcedUploadQueue lastObject];
          if (queuedBlock) {
            dispatch_async(self->_coordinationQueue, ^{
              queuedBlock();
            });
          }
        }
      });
    };
  });
  return onCompleteBlock;
}

#pragma mark - Private helper methods

/** Starts a timer that checks whether or not events can be uploaded at regular intervals. It will
 * check the next-upload clocks of all targets to determine if an upload attempt can be made.
 */
- (void)startTimer {
  dispatch_sync(_coordinationQueue, ^{
    self->_timer =
        dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self->_coordinationQueue);
    dispatch_source_set_timer(self->_timer, DISPATCH_TIME_NOW, self->_timerInterval,
                              self->_timerLeeway);
    dispatch_source_set_event_handler(self->_timer, ^{
      if (!self->_runningInBackground) {
        [self checkPrioritizersAndUploadEvents];
      }
    });
    dispatch_resume(self->_timer);
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
  dispatch_async(_coordinationQueue, ^{
    if (self->_runningInBackground) {
      return;
    }

    GDTUploadConditions conds = [self uploadConditions];
    if ((conds & GDTUploadConditionNoNetwork) == GDTUploadConditionNoNetwork) {
      return;
    }

    static int count = 0;
    count++;
    NSArray<NSNumber *> *targetsReadyForUpload = [self targetsReadyForUpload];
    for (NSNumber *target in targetsReadyForUpload) {
      id<GDTPrioritizer> prioritizer = self->_registrar.targetToPrioritizer[target];
      id<GDTUploader> uploader = self->_registrar.targetToUploader[target];
      GDTAssert(prioritizer && uploader, @"Target '%@' is missing an implementation", target);
      GDTUploadPackage *package = [[prioritizer uploadPackageWithConditions:conds] copy];
      package.storage = self.storage;
      if (package.events && package.events.count > 0) {
        self->_targetToInFlightEventSet[target] = package.events;
        [uploader uploadPackage:package onComplete:self.onCompleteBlock];
      }
    }
  });
}

/** Returns the current upload conditions after making determinations about the network connection.
 *
 * @return The current upload conditions.
 */
- (GDTUploadConditions)uploadConditions {
  SCNetworkReachabilityFlags currentFlags = [GDTReachability currentFlags];

  BOOL reachable =
      (currentFlags & kSCNetworkReachabilityFlagsReachable) == kSCNetworkReachabilityFlagsReachable;
  BOOL connectionRequired = (currentFlags & kSCNetworkReachabilityFlagsConnectionRequired) ==
                            kSCNetworkReachabilityFlagsConnectionRequired;
  BOOL interventionRequired = (currentFlags & kSCNetworkReachabilityFlagsInterventionRequired) ==
                              kSCNetworkReachabilityFlagsInterventionRequired;
  BOOL connectionOnDemand = (currentFlags & kSCNetworkReachabilityFlagsConnectionOnDemand) ==
                            kSCNetworkReachabilityFlagsConnectionOnDemand;
  BOOL connectionOnTraffic = (currentFlags & kSCNetworkReachabilityFlagsConnectionOnTraffic) ==
                             kSCNetworkReachabilityFlagsConnectionOnTraffic;
  BOOL isWWAN =
      (currentFlags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN;

  if (!reachable) {
    return GDTUploadConditionNoNetwork;
  }

  GDTUploadConditions conditions = 0;
  conditions |= !connectionRequired ? GDTUploadConditionWifiData : conditions;
  conditions |= isWWAN ? GDTUploadConditionMobileData : conditions;
  if ((connectionOnTraffic || connectionOnDemand) && !interventionRequired) {
    conditions = GDTUploadConditionWifiData;
  }

  BOOL wifi = (conditions & GDTUploadConditionWifiData) == GDTUploadConditionWifiData;
  BOOL cell = (conditions & GDTUploadConditionMobileData) == GDTUploadConditionMobileData;

  if (!(wifi || cell)) {
    conditions = GDTUploadConditionUnclearConnection;
  }

  return conditions;
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

#pragma mark - NSSecureCoding support

/** The keyed archiver key for the _targetToNextUploadTimes property. */
static NSString *const kTargetToNextUploadTimesKey =
    @"GDTUploadCoordinatorTargetToNextUploadTimesKey";

/** The keyed archiver key for the _targetToInFlightEventSet property. */
static NSString *const kTargetToInFlightEventSetKey =
    @"GDTUploadCoordinatorTargetToInFlightEventSetKey";

/** The keyed archiver key for the _forcedUploadQueue property. */
static NSString *const kForcedUploadQueueKey = @"GDTUploadCoordinatorForcedUploadQueueKey";

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  GDTUploadCoordinator *sharedInstance = [self.class sharedInstance];
  dispatch_sync(sharedInstance->_coordinationQueue, ^{
    sharedInstance->_targetToNextUploadTimes =
        [aDecoder decodeObjectOfClass:[NSMutableDictionary class]
                               forKey:kTargetToNextUploadTimesKey];
    sharedInstance->_targetToInFlightEventSet =
        [aDecoder decodeObjectOfClass:[NSMutableDictionary class]
                               forKey:kTargetToInFlightEventSetKey];
    sharedInstance->_forcedUploadQueue = [aDecoder decodeObjectOfClass:[NSMutableArray class]
                                                                forKey:kForcedUploadQueueKey];
  });
  return sharedInstance;
}

// Needs to always be called on the queue to be thread-safe.
- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self->_targetToNextUploadTimes forKey:kTargetToNextUploadTimesKey];
  [aCoder encodeObject:self->_targetToInFlightEventSet forKey:kTargetToInFlightEventSetKey];
  [aCoder encodeObject:self->_forcedUploadQueue forKey:kForcedUploadQueueKey];
}

#pragma mark - GDTLifecycleProtocol

- (void)appWillForeground:(UIApplication *)app {
  // Not entirely thread-safe, but it should be fine.
  self->_runningInBackground = NO;
  [self startTimer];
  [NSKeyedUnarchiver unarchiveObjectWithFile:[GDTUploadCoordinator archivePath]];
}

- (void)appWillBackground:(UIApplication *)app {
  // Not entirely thread-safe, but it should be fine.
  self->_runningInBackground = YES;

  // Should be thread-safe. If it ends up not being, put this in a dispatch_sync.
  [self stopTimer];

  // Create an immediate background task to run until the end of the current queue of work.
  __block UIBackgroundTaskIdentifier bgID = [app beginBackgroundTaskWithExpirationHandler:^{
    [NSKeyedArchiver archiveRootObject:self toFile:[GDTUploadCoordinator archivePath]];
    [app endBackgroundTask:bgID];
  }];
  dispatch_async(_coordinationQueue, ^{
    [NSKeyedArchiver archiveRootObject:self toFile:[GDTUploadCoordinator archivePath]];
    [app endBackgroundTask:bgID];
  });
}

- (void)appWillTerminate:(UIApplication *)application {
  dispatch_sync(_coordinationQueue, ^{
    [self stopTimer];
    [NSKeyedArchiver archiveRootObject:self toFile:[GDTUploadCoordinator archivePath]];
  });
}

@end
