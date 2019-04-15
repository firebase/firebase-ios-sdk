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

#import "GDTStorage.h"
#import "GDTStorage_Private.h"

#import <GoogleDataTransport/GDTPrioritizer.h>
#import <GoogleDataTransport/GDTStoredEvent.h>

#import "GDTAssert.h"
#import "GDTConsoleLogger.h"
#import "GDTEvent_Private.h"
#import "GDTLifecycle.h"
#import "GDTRegistrar_Private.h"
#import "GDTUploadCoordinator.h"

/** Creates and/or returns a singleton NSString that is the shared storage path.
 *
 * @return The SDK event storage path.
 */
static NSString *GDTStoragePath() {
  static NSString *storagePath;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSString *cachePath =
        NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    storagePath = [NSString stringWithFormat:@"%@/google-sdks-events", cachePath];
  });
  return storagePath;
}

@implementation GDTStorage

+ (NSString *)archivePath {
  static NSString *archivePath;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    archivePath = [GDTStoragePath() stringByAppendingPathComponent:@"GDTStorageArchive"];
  });
  return archivePath;
}

+ (instancetype)sharedInstance {
  static GDTStorage *sharedStorage;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedStorage = [[GDTStorage alloc] init];
  });
  return sharedStorage;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _storageQueue = dispatch_queue_create("com.google.GDTStorage", DISPATCH_QUEUE_SERIAL);
    _targetToEventSet = [[NSMutableDictionary alloc] init];
    _storedEvents = [[NSMutableOrderedSet alloc] init];
    _uploader = [GDTUploadCoordinator sharedInstance];
  }
  return self;
}

- (void)storeEvent:(GDTEvent *)event {
  [self createEventDirectoryIfNotExists];

  __block UIBackgroundTaskIdentifier bgID = UIBackgroundTaskInvalid;
  if (_runningInBackground) {
    bgID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
      [[UIApplication sharedApplication] endBackgroundTask:bgID];
    }];
  }

  dispatch_async(_storageQueue, ^{
    // Check that a backend implementation is available for this target.
    NSInteger target = event.target;

    // Check that a prioritizer is available for this target.
    id<GDTPrioritizer> prioritizer = [GDTRegistrar sharedInstance].targetToPrioritizer[@(target)];
    GDTAssert(prioritizer, @"There's no prioritizer registered for the given target.");

    // Write the transport bytes to disk, get a filename.
    GDTAssert(event.dataObjectTransportBytes, @"The event should have been serialized to bytes");
    NSURL *eventFile = [self saveEventBytesToDisk:event.dataObjectTransportBytes
                                        eventHash:event.hash];
    GDTStoredEvent *storedEvent = [event storedEventWithFileURL:eventFile];

    // Add event to tracking collections.
    [self addEventToTrackingCollections:storedEvent];

    // Have the prioritizer prioritize the event.
    [prioritizer prioritizeEvent:storedEvent];

    // Check the QoS, if it's high priority, notify the target that it has a high priority event.
    if (event.qosTier == GDTEventQoSFast) {
      [self.uploader forceUploadForTarget:target];
    }

    // If running in the background, save state to disk and end the associated background task.
    if (bgID != UIBackgroundTaskInvalid) {
      [NSKeyedArchiver archiveRootObject:self toFile:[GDTStorage archivePath]];
      [[UIApplication sharedApplication] endBackgroundTask:bgID];
    }
  });
}

- (void)removeEvents:(NSSet<GDTStoredEvent *> *)events {
  NSSet<GDTStoredEvent *> *eventsToRemove = [events copy];
  GDTStoredEvent *anyEvent = [eventsToRemove anyObject];
  id<GDTPrioritizer> prioritizer =
      [GDTRegistrar sharedInstance].targetToPrioritizer[anyEvent.target];
  GDTAssert(prioritizer, @"There must be a prioritizer.");
  [prioritizer unprioritizeEvents:events];

  dispatch_async(_storageQueue, ^{
    for (GDTStoredEvent *event in eventsToRemove) {
      // Remove from disk, first and foremost.
      NSError *error;
      [[NSFileManager defaultManager] removeItemAtURL:event.eventFileURL error:&error];
      GDTAssert(error == nil, @"There was an error removing an event file: %@", error);
      GDTAssert([GDTRegistrar sharedInstance].targetToPrioritizer[event.target] == prioritizer,
                @"All logs within an upload set should have the same prioritizer.");

      // Remove from the tracking collections.
      [self.storedEvents removeObject:event];
      [self.targetToEventSet[event.target] removeObject:event];
    }
  });
}

#pragma mark - Private helper methods

/** Creates the storage directory if it does not exist. */
- (void)createEventDirectoryIfNotExists {
  NSError *error;
  BOOL result = [[NSFileManager defaultManager] createDirectoryAtPath:GDTStoragePath()
                                          withIntermediateDirectories:YES
                                                           attributes:0
                                                                error:&error];
  if (!result || error) {
    GDTLogError(GDTMCEDirectoryCreationError, @"Error creating the directory: %@", error);
  }
}

/** Saves the event's dataObjectTransportBytes to a file using NSData mechanisms.
 *
 * @note This method should only be called from a method within a block on _storageQueue to maintain
 * thread safety.
 *
 * @param transportBytes The transport bytes of the event.
 * @param eventHash The hash value of the event.
 * @return The filename
 */
- (NSURL *)saveEventBytesToDisk:(NSData *)transportBytes eventHash:(NSUInteger)eventHash {
  NSString *storagePath = GDTStoragePath();
  NSString *event = [NSString stringWithFormat:@"event-%lu", (unsigned long)eventHash];
  NSURL *eventFilePath = [NSURL fileURLWithPath:[storagePath stringByAppendingPathComponent:event]];

  GDTAssert(![[NSFileManager defaultManager] fileExistsAtPath:eventFilePath.path],
            @"An event shouldn't already exist at this path: %@", eventFilePath.path);

  BOOL writingSuccess = [transportBytes writeToURL:eventFilePath atomically:YES];
  if (!writingSuccess) {
    GDTLogError(GDTMCEFileWriteError, @"An event file could not be written: %@", eventFilePath);
  }

  return eventFilePath;
}

/** Adds the event to internal tracking collections.
 *
 * @note This method should only be called from a method within a block on _storageQueue to maintain
 * thread safety.
 *
 * @param event The event to track.
 */
- (void)addEventToTrackingCollections:(GDTStoredEvent *)event {
  [_storedEvents addObject:event];
  NSMutableSet<GDTStoredEvent *> *events = self.targetToEventSet[event.target];
  events = events ? events : [[NSMutableSet alloc] init];
  [events addObject:event];
  _targetToEventSet[event.target] = events;
}

#pragma mark - GDTLifecycleProtocol

- (void)appWillForeground:(UIApplication *)app {
  [NSKeyedUnarchiver unarchiveObjectWithFile:[GDTStorage archivePath]];
  self->_runningInBackground = NO;
}

- (void)appWillBackground:(UIApplication *)app {
  self->_runningInBackground = YES;
  [NSKeyedArchiver archiveRootObject:self toFile:[GDTStorage archivePath]];
  // Create an immediate background task to run until the end of the current queue of work.
  __block UIBackgroundTaskIdentifier bgID = [app beginBackgroundTaskWithExpirationHandler:^{
    [app endBackgroundTask:bgID];
  }];
  dispatch_async(_storageQueue, ^{
    [app endBackgroundTask:bgID];
  });
}

- (void)appWillTerminate:(UIApplication *)application {
  [NSKeyedArchiver archiveRootObject:self toFile:[GDTStorage archivePath]];
}

#pragma mark - NSSecureCoding

/** The NSKeyedCoder key for the storedEvents property. */
static NSString *const kGDTStorageStoredEventsKey = @"GDTStorageStoredEventsKey";

/** The NSKeyedCoder key for the targetToEventSet property. */
static NSString *const kGDTStorageTargetToEventSetKey = @"GDTStorageTargetToEventSetKey";

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  // Create the singleton and populate its ivars.
  GDTStorage *sharedInstance = [self.class sharedInstance];
  dispatch_sync(sharedInstance.storageQueue, ^{
    sharedInstance->_storedEvents = [aDecoder decodeObjectOfClass:[NSMutableOrderedSet class]
                                                           forKey:kGDTStorageStoredEventsKey];
    sharedInstance->_targetToEventSet =
        [aDecoder decodeObjectOfClass:[NSMutableDictionary class]
                               forKey:kGDTStorageTargetToEventSetKey];
  });
  return sharedInstance;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  GDTStorage *sharedInstance = [self.class sharedInstance];
  dispatch_sync(sharedInstance.storageQueue, ^{
    [aCoder encodeObject:sharedInstance->_storedEvents forKey:kGDTStorageStoredEventsKey];
    [aCoder encodeObject:sharedInstance->_targetToEventSet forKey:kGDTStorageTargetToEventSetKey];
  });
}

@end
