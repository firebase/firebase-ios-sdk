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

#import "GDTCORLibrary/Private/GDTCORStorage.h"
#import "GDTCORLibrary/Private/GDTCORStorage_Private.h"

#import <GoogleDataTransport/GDTCORAssert.h>
#import <GoogleDataTransport/GDTCORConsoleLogger.h>
#import <GoogleDataTransport/GDTCOREvent.h>
#import <GoogleDataTransport/GDTCORLifecycle.h>
#import <GoogleDataTransport/GDTCORPrioritizer.h>

#import "GDTCORLibrary/Private/GDTCOREvent_Private.h"
#import "GDTCORLibrary/Private/GDTCORRegistrar_Private.h"
#import "GDTCORLibrary/Private/GDTCORUploadCoordinator.h"

@implementation GDTCORStorage

+ (NSString *)archivePath {
  static NSString *archivePath;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    archivePath = [GDTCORRootDirectory() URLByAppendingPathComponent:@"GDTCORStorageArchive"].path;
  });
  return archivePath;
}

+ (instancetype)sharedInstance {
  static GDTCORStorage *sharedStorage;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedStorage = [[GDTCORStorage alloc] init];
  });
  return sharedStorage;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _storageQueue = dispatch_queue_create("com.google.GDTCORStorage", DISPATCH_QUEUE_SERIAL);
    _targetToEventSet = [[NSMutableDictionary alloc] init];
    _storedEvents = [[NSMutableOrderedSet alloc] init];
    _uploadCoordinator = [GDTCORUploadCoordinator sharedInstance];
  }
  return self;
}

- (void)storeEvent:(GDTCOREvent *)event
        onComplete:(void (^_Nullable)(BOOL wasWritten, NSError *error))completion {
  GDTCORLogDebug("Saving event: %@", event);
  if (event == nil) {
    GDTCORLogDebug("%@", @"The event was nil, so it was not saved.");
    return;
  }
  BOOL hadOriginalCompletion = completion != nil;
  if (!completion) {
    completion = ^(BOOL wasWritten, NSError *error) {
      GDTCORLogDebug(@"event %@ stored. success:%@ error:%@", event, wasWritten ? @"YES" : @"NO",
                     error);
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
    GDTCORLogDebug("Event saved to disk: %@", eventFile);
    completion(eventFile != nil, error);

    // Add event to tracking collections.
    [self addEventToTrackingCollections:event];

    // Have the prioritizer prioritize the event and save state if there was an onComplete block.
    [prioritizer prioritizeEvent:event];
    if (hadOriginalCompletion && [prioritizer respondsToSelector:@selector(saveState)]) {
      [prioritizer saveState];
      GDTCORLogDebug(@"Prioritizer %@ has saved state due to an event's onComplete block.",
                     prioritizer);
    }

    // Check the QoS, if it's high priority, notify the target that it has a high priority event.
    if (event.qosTier == GDTCOREventQoSFast) {
      [self.uploadCoordinator forceUploadForTarget:target];
    }

    // Write state to disk if there was an onComplete block or if we're in the background.
    if (hadOriginalCompletion || [[GDTCORApplication sharedApplication] isRunningInBackground]) {
      if (hadOriginalCompletion) {
        GDTCORLogDebug("%@", @"Saving storage state because a completion block was passed.");
      } else {
        GDTCORLogDebug("%@", @"Saving storage state because the app is running in the background");
      }
      NSError *error;
      GDTCOREncodeArchive(self, [GDTCORStorage archivePath], &error);
      if (error) {
        GDTCORLogDebug(@"Serializing GDTCORStorage to an archive failed: %@", error);
      }
    }

    // Cancel or end the associated background task if it's still valid.
    [[GDTCORApplication sharedApplication] endBackgroundTask:bgID];
    bgID = GDTCORBackgroundIdentifierInvalid;
    GDTCORLogDebug("Event %@ is stored. There are %ld events stored on disk", event,
                   (unsigned long)self->_storedEvents.count);
  });
}

- (void)removeEvents:(NSSet<GDTCOREvent *> *)events {
  NSSet<GDTCOREvent *> *eventsToRemove = [events copy];
  dispatch_async(_storageQueue, ^{
    for (GDTCOREvent *event in eventsToRemove) {
      // Remove from disk, first and foremost.
      NSError *error;
      if (event.fileURL) {
        NSURL *fileURL = event.fileURL;
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:&error];
        GDTCORAssert(error == nil, @"There was an error removing an event file: %@", error);
        GDTCORLogDebug("Removed event from disk: %@", fileURL);
      }

      // Remove from the tracking collections.
      [self.storedEvents removeObject:event];
      [self.targetToEventSet[@(event.target)] removeObject:event];
    }
  });
}

#pragma mark - Private helper methods

/** Creates the storage directory if it does not exist. */
- (void)createEventDirectoryIfNotExists {
  NSError *error;
  BOOL result = [[NSFileManager defaultManager] createDirectoryAtURL:GDTCORRootDirectory()
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
  NSString *eventFileName = [NSString stringWithFormat:@"event-%lu", (unsigned long)eventHash];
  NSError *writingError;
  [event writeToGDTPath:eventFileName error:&writingError];
  if (writingError) {
    GDTCORLogDebug(@"There was an error saving an event to disk: %@", writingError);
  }
  return event.fileURL;
}

/** Adds the event to internal tracking collections.
 *
 * @note This method should only be called from a method within a block on _storageQueue to maintain
 * thread safety.
 *
 * @param event The event to track.
 */
- (void)addEventToTrackingCollections:(GDTCOREvent *)event {
  [_storedEvents addObject:event];
  NSNumber *target = @(event.target);
  NSMutableSet<GDTCOREvent *> *events = self.targetToEventSet[target];
  events = events ? events : [[NSMutableSet alloc] init];
  [events addObject:event];
  _targetToEventSet[target] = events;
}

#pragma mark - GDTCORLifecycleProtocol

- (void)appWillForeground:(GDTCORApplication *)app {
  NSError *error;
  GDTCORDecodeArchive([GDTCORStorage class], [GDTCORStorage archivePath], nil, &error);
  if (error) {
    GDTCORLogDebug(@"Deserializing GDTCORStorage from an archive failed: %@", error);
  }
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
    NSError *error;
    GDTCOREncodeArchive(self, [GDTCORStorage archivePath], &error);
    if (error) {
      GDTCORLogDebug(@"Serializing GDTCORStorage to an archive failed: %@", error);
    } else {
      GDTCORLogDebug(@"Serialized GDTCORStorage to %@", [GDTCORStorage archivePath]);
    }

    // End the background task if it's still valid.
    [app endBackgroundTask:bgID];
    bgID = GDTCORBackgroundIdentifierInvalid;
  });
}

- (void)appWillTerminate:(GDTCORApplication *)application {
  dispatch_sync(_storageQueue, ^{
    NSError *error;
    GDTCOREncodeArchive(self, [GDTCORStorage archivePath], &error);
    if (error) {
      GDTCORLogDebug(@"Serializing GDTCORStorage to an archive failed: %@", error);
    } else {
      GDTCORLogDebug(@"Serialized GDTCORStorage to %@", [GDTCORStorage archivePath]);
    }
  });
}

#pragma mark - NSSecureCoding

/** The NSKeyedCoder key for the storedEvents property. */
static NSString *const kGDTCORStorageStoredEventsKey = @"GDTCORStorageStoredEventsKey";

/** The NSKeyedCoder key for the targetToEventSet property. */
static NSString *const kGDTCORStorageTargetToEventSetKey = @"GDTCORStorageTargetToEventSetKey";

/** The NSKeyedCoder key for the uploadCoordinator property. */
static NSString *const kGDTCORStorageUploadCoordinatorKey = @"GDTCORStorageUploadCoordinatorKey";

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  // Sets a global translation mapping to decode GDTCORStoredEvent objects encoded as instances of
  // GDTCOREvent instead.
  [NSKeyedUnarchiver setClass:[GDTCOREvent class] forClassName:@"GDTCORStoredEvent"];

  // Create the singleton and populate its ivars.
  GDTCORStorage *sharedInstance = [self.class sharedInstance];
  dispatch_sync(sharedInstance.storageQueue, ^{
    NSSet *classes = [NSSet setWithObjects:[NSMutableOrderedSet class], [GDTCOREvent class], nil];
    sharedInstance->_storedEvents = [aDecoder decodeObjectOfClasses:classes
                                                             forKey:kGDTCORStorageStoredEventsKey];
    classes = [NSSet
        setWithObjects:[NSMutableDictionary class], [NSMutableSet class], [GDTCOREvent class], nil];
    sharedInstance->_targetToEventSet =
        [aDecoder decodeObjectOfClasses:classes forKey:kGDTCORStorageTargetToEventSetKey];
    sharedInstance->_uploadCoordinator =
        [aDecoder decodeObjectOfClass:[GDTCORUploadCoordinator class]
                               forKey:kGDTCORStorageUploadCoordinatorKey];
  });
  return sharedInstance;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  GDTCORStorage *sharedInstance = [self.class sharedInstance];
  NSMutableOrderedSet<GDTCOREvent *> *storedEvents = sharedInstance->_storedEvents;
  if (storedEvents) {
    [aCoder encodeObject:storedEvents forKey:kGDTCORStorageStoredEventsKey];
  }
  NSMutableDictionary<NSNumber *, NSMutableSet<GDTCOREvent *> *> *targetToEventSet =
      sharedInstance->_targetToEventSet;
  if (targetToEventSet) {
    [aCoder encodeObject:targetToEventSet forKey:kGDTCORStorageTargetToEventSetKey];
  }
  GDTCORUploadCoordinator *uploadCoordinator = sharedInstance->_uploadCoordinator;
  if (uploadCoordinator) {
    [aCoder encodeObject:uploadCoordinator forKey:kGDTCORStorageUploadCoordinatorKey];
  }
}

@end
