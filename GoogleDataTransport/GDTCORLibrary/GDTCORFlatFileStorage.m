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

#import "GDTCORLibrary/Private/GDTCORFlatFileStorage.h"

#import <GoogleDataTransport/GDTCORAssert.h>
#import <GoogleDataTransport/GDTCORConsoleLogger.h>
#import <GoogleDataTransport/GDTCOREvent.h>
#import <GoogleDataTransport/GDTCORLifecycle.h>
#import <GoogleDataTransport/GDTCORPrioritizer.h>

#import "GDTCORLibrary/Private/GDTCOREvent_Private.h"
#import "GDTCORLibrary/Private/GDTCORRegistrar_Private.h"
#import "GDTCORLibrary/Private/GDTCORUploadCoordinator.h"

/** Creates and/or returns a singleton NSString that is the shared storage path.
 *
 * @return The SDK event storage path.
 */
static NSString *GDTCORFlatFileStoragePath() {
  static NSString *storagePath;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSString *cachePath =
        NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    storagePath = [NSString stringWithFormat:@"%@/google-sdks-events", cachePath];
    GDTCORLogDebug("Events will be saved to %@", storagePath);
  });
  return storagePath;
}

@implementation GDTCORFlatFileStorage

+ (void)load {
  [[GDTCORRegistrar sharedInstance] registerStorage:[self sharedInstance] target:kGDTCORTargetCCT];
  [[GDTCORRegistrar sharedInstance] registerStorage:[self sharedInstance] target:kGDTCORTargetFLL];
  [[GDTCORRegistrar sharedInstance] registerStorage:[self sharedInstance] target:kGDTCORTargetCSH];

  // Sets a global translation mapping to decode GDTCORStoredEvent objects encoded as instances of
  // GDTCOREvent instead. Then we do the same thing with GDTCORStorage. This must be done in load
  // because there are no direct references to this class and the NSCoding methods won't be called
  // unless the class name is mapped early.
  [NSKeyedUnarchiver setClass:[GDTCOREvent class] forClassName:@"GDTCORStoredEvent"];
  [NSKeyedUnarchiver setClass:[GDTCORFlatFileStorage class] forClassName:@"GDTCORStorage"];
}

+ (NSString *)archivePath {
  static NSString *archivePath;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    archivePath = [GDTCORFlatFileStoragePath()
        stringByAppendingPathComponent:@"GDTCORFlatFileStorageArchive"];
  });
  return archivePath;
}

+ (instancetype)sharedInstance {
  static GDTCORFlatFileStorage *sharedStorage;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedStorage = [[GDTCORFlatFileStorage alloc] init];
  });
  return sharedStorage;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _storageQueue =
        dispatch_queue_create("com.google.GDTCORFlatFileStorage", DISPATCH_QUEUE_SERIAL);
    _targetToEventSet = [[NSMutableDictionary alloc] init];
    _storedEvents = [[NSMutableDictionary alloc] init];
    _uploadCoordinator = [GDTCORUploadCoordinator sharedInstance];
  }
  return self;
}

- (void)storeEvent:(GDTCOREvent *)event onComplete:(void (^)(NSError *error))completion {
  GDTCORLogDebug("Saving event: %@", event);
  if (event == nil) {
    GDTCORLogDebug("%@", @"The event was nil, so it was not saved.");
    return;
  }
  if (!completion) {
    completion = ^(NSError *error) {
    };
  }

  [self createEventDirectoryIfNotExists];

  __block GDTCORBackgroundIdentifier bgID = GDTCORBackgroundIdentifierInvalid;
  bgID = [[GDTCORApplication sharedApplication]
      beginBackgroundTaskWithName:@"GDTStorage"
                expirationHandler:^{
                  // End the background task if it's still valid.
                  [[GDTCORApplication sharedApplication] endBackgroundTask:bgID];
                  bgID = GDTCORBackgroundIdentifierInvalid;
                }];

  dispatch_async(_storageQueue, ^{
    // Check that a backend implementation is available for this target.
    NSInteger target = event.target;

    // Check that a prioritizer is available for this target.
    id<GDTCORPrioritizer> prioritizer =
        [GDTCORRegistrar sharedInstance].targetToPrioritizer[@(target)];
    GDTCORAssert(prioritizer, @"There's no prioritizer registered for the given target. Are you "
                              @"sure you've added the support library for the backend you need?");

    // Write the transport bytes to disk, get a filename.
    GDTCORAssert([event.dataObject transportBytes],
                 @"The event should have been serialized to bytes");
    NSError *error = nil;
    NSURL *eventFile = [self saveEventBytesToDisk:event eventHash:event.hash error:&error];
    if (!eventFile || error) {
      GDTCORLogError(GDTCORMCEFileWriteError, @"Event failed to save to disk: %@", error);
    } else {
      GDTCORLogDebug("Event saved to disk: %@", eventFile);
    }

    // Add event to tracking collections.
    [self addEventToTrackingCollections:event];

    completion(error);

    // Have the prioritizer prioritize the event.
    [prioritizer prioritizeEvent:event];

    // Check the QoS, if it's high priority, notify the target that it has a high priority event.
    if (event.qosTier == GDTCOREventQoSFast) {
      [self.uploadCoordinator forceUploadForTarget:target];
    }

    // Write state to disk if we're in the background.
    if ([[GDTCORApplication sharedApplication] isRunningInBackground]) {
      GDTCORLogDebug("%@", @"Saving storage state because the app is running in the background");
      if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
        NSError *error;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self
                                             requiringSecureCoding:YES
                                                             error:&error];
        [data writeToFile:[GDTCORFlatFileStorage archivePath] atomically:YES];
      } else {
#if !TARGET_OS_MACCATALYST && !TARGET_OS_WATCH
        [NSKeyedArchiver archiveRootObject:self toFile:[GDTCORFlatFileStorage archivePath]];
#endif
      }
    }

    // Cancel or end the associated background task if it's still valid.
    [[GDTCORApplication sharedApplication] endBackgroundTask:bgID];
    bgID = GDTCORBackgroundIdentifierInvalid;
    GDTCORLogDebug("Event %@ is stored. There are %ld events stored on disk", event,
                   (unsigned long)self->_storedEvents.count);
  });
}

- (void)removeEvents:(NSSet<NSNumber *> *)eventIDs {
  NSSet<NSNumber *> *eventsToRemove = [eventIDs copy];
  dispatch_async(_storageQueue, ^{
    for (NSNumber *eventID in eventsToRemove) {
      // Remove from disk, first and foremost.
      GDTCOREvent *event = self->_storedEvents[eventID];
      if (event) {
        NSError *error;
        if (event.fileURL) {
          NSURL *fileURL = event.fileURL;
          [[NSFileManager defaultManager] removeItemAtURL:fileURL error:&error];
          GDTCORAssert(error == nil, @"There was an error removing an event file: %@", error);
          GDTCORLogDebug("Removed event from disk: %@", fileURL);
        }

        // Remove from the tracking collections.
        [self.storedEvents removeObjectForKey:event.eventID];
        [self.targetToEventSet[@(event.target)] removeObject:event];
      }
    }
  });
}

#pragma mark - Private helper methods

/** Creates the storage directory if it does not exist. */
- (void)createEventDirectoryIfNotExists {
  NSError *error;
  BOOL result = [[NSFileManager defaultManager] createDirectoryAtPath:GDTCORFlatFileStoragePath()
                                          withIntermediateDirectories:YES
                                                           attributes:0
                                                                error:&error];
  if (!result || error) {
    GDTCORLogError(GDTCORMCEDirectoryCreationError, @"Error creating the directory: %@", error);
  }
}

/** Saves the event's dataObject to a file using NSData mechanisms.
 *
 * @note This method should only be called from a method within a block on _storageQueue to maintain
 * thread safety.
 *
 * @param event The event.
 * @param eventHash The hash value of the event.
 * @return The filename
 */
- (NSURL *)saveEventBytesToDisk:(GDTCOREvent *)event
                      eventHash:(NSUInteger)eventHash
                          error:(NSError **)error {
  NSString *storagePath = GDTCORFlatFileStoragePath();
  NSString *eventFileName = [NSString stringWithFormat:@"event-%lu", (unsigned long)eventHash];
  NSURL *eventFilePath =
      [NSURL fileURLWithPath:[storagePath stringByAppendingPathComponent:eventFileName]];

  GDTCORAssert(![[NSFileManager defaultManager] fileExistsAtPath:eventFilePath.path],
               @"An event shouldn't already exist at this path: %@", eventFilePath.path);

  [event writeToURL:eventFilePath error:error];
  return eventFilePath;
}

/** Adds the event to internal tracking collections.
 *
 * @note This method should only be called from a method within a block on _storageQueue to maintain
 * thread safety.
 *
 * @param event The event to track.
 */
- (void)addEventToTrackingCollections:(GDTCOREvent *)event {
  _storedEvents[event.eventID] = event;
  NSNumber *target = @(event.target);
  NSMutableSet<GDTCOREvent *> *events = self.targetToEventSet[target];
  events = events ? events : [[NSMutableSet alloc] init];
  [events addObject:event];
  _targetToEventSet[target] = events;
}

#pragma mark - GDTCORLifecycleProtocol

- (void)appWillForeground:(GDTCORApplication *)app {
  dispatch_async(_storageQueue, ^{
    if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
      NSError *error;
      NSData *data = [NSData dataWithContentsOfFile:[GDTCORFlatFileStorage archivePath]];
      if (data) {
        [NSKeyedUnarchiver unarchivedObjectOfClass:[GDTCORFlatFileStorage class]
                                          fromData:data
                                             error:&error];
      }
    } else {
#if !TARGET_OS_MACCATALYST && !TARGET_OS_WATCH
      [NSKeyedUnarchiver unarchiveObjectWithFile:[GDTCORFlatFileStorage archivePath]];
#endif
    }
  });
}

- (void)appWillBackground:(GDTCORApplication *)app {
  dispatch_async(_storageQueue, ^{
    // Immediately request a background task to run until the end of the current queue of work, and
    // cancel it once the work is done.
    __block GDTCORBackgroundIdentifier bgID =
        [app beginBackgroundTaskWithName:@"GDTStorage"
                       expirationHandler:^{
                         [app endBackgroundTask:bgID];
                         bgID = GDTCORBackgroundIdentifierInvalid;
                       }];

    if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
      NSError *error;
      NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self
                                           requiringSecureCoding:YES
                                                           error:&error];
      [data writeToFile:[GDTCORFlatFileStorage archivePath] atomically:YES];
    } else {
#if !TARGET_OS_MACCATALYST && !TARGET_OS_WATCH
      [NSKeyedArchiver archiveRootObject:self toFile:[GDTCORFlatFileStorage archivePath]];
#endif
    }

    // End the background task if it's still valid.
    [app endBackgroundTask:bgID];
    bgID = GDTCORBackgroundIdentifierInvalid;
  });
}

- (void)appWillTerminate:(GDTCORApplication *)application {
  dispatch_sync(_storageQueue, ^{
    if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
      NSError *error;
      NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self
                                           requiringSecureCoding:YES
                                                           error:&error];
      [data writeToFile:[GDTCORFlatFileStorage archivePath] atomically:YES];
    } else {
#if !TARGET_OS_MACCATALYST && !TARGET_OS_WATCH
      [NSKeyedArchiver archiveRootObject:self toFile:[GDTCORFlatFileStorage archivePath]];
#endif
    }
  });
}

#pragma mark - NSSecureCoding

/** The NSKeyedCoder key for the storedEvents property. */
static NSString *const kGDTCORFlatFileStorageStoredEventsKey = @"GDTCORStorageStoredEventsKey";

/** The NSKeyedCoder key for the targetToEventSet property. */
static NSString *const kGDTCORFlatFileStorageTargetToEventSetKey =
    @"GDTCORStorageTargetToEventSetKey";

/** The NSKeyedCoder key for the uploadCoordinator property. */
static NSString *const kGDTCORFlatFileStorageUploadCoordinatorKey =
    @"GDTCORStorageUploadCoordinatorKey";

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  // Create the singleton and populate its ivars.
  GDTCORFlatFileStorage *sharedInstance = [self.class sharedInstance];
  NSSet *classes = [NSSet setWithObjects:[NSMutableOrderedSet class], [NSMutableDictionary class],
                                         [GDTCOREvent class], nil];
  id storedEvents = [aDecoder decodeObjectOfClasses:classes
                                             forKey:kGDTCORFlatFileStorageStoredEventsKey];
  NSMutableDictionary<NSNumber *, GDTCOREvent *> *events = [[NSMutableDictionary alloc] init];
  if ([storedEvents isKindOfClass:[NSMutableOrderedSet class]]) {
    [(NSMutableOrderedSet *)storedEvents
        enumerateObjectsUsingBlock:^(GDTCOREvent *_Nonnull obj, NSUInteger idx,
                                     BOOL *_Nonnull stop) {
          events[obj.eventID] = obj;
        }];
  } else if ([storedEvents isKindOfClass:[NSMutableDictionary class]]) {
    events = (NSMutableDictionary *)storedEvents;
  }
  sharedInstance->_storedEvents = events;
  classes = [NSSet
      setWithObjects:[NSMutableDictionary class], [NSMutableSet class], [GDTCOREvent class], nil];
  sharedInstance->_targetToEventSet =
      [aDecoder decodeObjectOfClasses:classes forKey:kGDTCORFlatFileStorageTargetToEventSetKey];
  sharedInstance->_uploadCoordinator =
      [aDecoder decodeObjectOfClass:[GDTCORUploadCoordinator class]
                             forKey:kGDTCORFlatFileStorageUploadCoordinatorKey];
  return sharedInstance;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  GDTCORFlatFileStorage *sharedInstance = [self.class sharedInstance];
  NSMutableDictionary<NSNumber *, GDTCOREvent *> *storedEvents = sharedInstance->_storedEvents;
  if (storedEvents) {
    [aCoder encodeObject:storedEvents forKey:kGDTCORFlatFileStorageStoredEventsKey];
  }
  NSMutableDictionary<NSNumber *, NSMutableSet<GDTCOREvent *> *> *targetToEventSet =
      sharedInstance->_targetToEventSet;
  if (targetToEventSet) {
    [aCoder encodeObject:targetToEventSet forKey:kGDTCORFlatFileStorageTargetToEventSetKey];
  }
  GDTCORUploadCoordinator *uploadCoordinator = sharedInstance->_uploadCoordinator;
  if (uploadCoordinator) {
    [aCoder encodeObject:uploadCoordinator forKey:kGDTCORFlatFileStorageUploadCoordinatorKey];
  }
}

@end
