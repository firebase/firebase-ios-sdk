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
#import <GoogleDataTransport/GDTCORPlatform.h>
#import <GoogleDataTransport/GDTCORPrioritizer.h>
#import <GoogleDataTransport/GDTCORStorageEventSelector.h>

#import "GDTCORLibrary/Private/GDTCOREvent_Private.h"
#import "GDTCORLibrary/Private/GDTCORFlatFileStorageIterator.h"
#import "GDTCORLibrary/Private/GDTCORRegistrar_Private.h"
#import "GDTCORLibrary/Private/GDTCORUploadCoordinator.h"

NSString *const gGDTCORFlatFileStorageEventDataPathKey = @"DataPath";

NSString *const gGDTCORFlatFileStorageMappingIDPathKey = @"MappingIDPath";

NSString *const gGDTCORFlatFileStorageQoSTierPathKey = @"QoSTierPath";

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
    archivePath =
        [GDTCORRootDirectory() URLByAppendingPathComponent:@"GDTCORFlatFileStorageArchive"].path;
  });
  return archivePath;
}

+ (NSString *)baseEventStoragePath {
  static NSString *eventDataPath;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    eventDataPath =
        [GDTCORRootDirectory() URLByAppendingPathComponent:NSStringFromClass([self class])
                                               isDirectory:YES]
            .path;
    eventDataPath = [eventDataPath stringByAppendingPathComponent:@"gdt_event_data"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:eventDataPath isDirectory:NULL]) {
      NSError *error;
      [[NSFileManager defaultManager] createDirectoryAtPath:eventDataPath
                                withIntermediateDirectories:YES
                                                 attributes:0
                                                      error:&error];
      GDTCORAssert(error == nil, @"Creating the library data path failed: %@", error);
    }
  });
  return eventDataPath;
}

+ (NSString *)libraryDataStoragePath {
  static NSString *libraryDataPath;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    libraryDataPath =
        [GDTCORRootDirectory() URLByAppendingPathComponent:NSStringFromClass([self class])
                                               isDirectory:YES]
            .path;
    libraryDataPath = [libraryDataPath stringByAppendingPathComponent:@"gdt_library_data"];
  });
  if (![[NSFileManager defaultManager] fileExistsAtPath:libraryDataPath isDirectory:NULL]) {
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:libraryDataPath
                              withIntermediateDirectories:YES
                                               attributes:0
                                                    error:&error];
    GDTCORAssert(error == nil, @"Creating the library data path failed: %@", error);
  }
  return libraryDataPath;
}

+ (NSDictionary<NSString *, NSString *> *)pathsForEvent:(GDTCOREvent *)event {
  NSString *dataPath =
      [NSString stringWithFormat:@"%@/%ld/%@", [GDTCORFlatFileStorage baseEventStoragePath],
                                 (long)event.target, event.eventID];
  NSString *mappingIDPath =
      [NSString stringWithFormat:@"%@/%ld/%@/%@", [GDTCORFlatFileStorage baseEventStoragePath],
                                 (long)event.target, event.mappingID, event.eventID];
  NSString *qosTierPath =
      [NSString stringWithFormat:@"%@/%ld/%ld/%@", [GDTCORFlatFileStorage baseEventStoragePath],
                                 (long)event.target, (long)event.qosTier, event.eventID];
  return @{
    gGDTCORFlatFileStorageEventDataPathKey : dataPath,
    gGDTCORFlatFileStorageMappingIDPathKey : mappingIDPath,
    gGDTCORFlatFileStorageQoSTierPathKey : qosTierPath
  };
}

+ (NSString *)pathForTarget:(GDTCORTarget)target
                    qosTier:(nullable NSNumber *)qosTier
                  mappingID:(nullable NSString *)mappingID {
  NSString *baseEventPath = [GDTCORFlatFileStorage baseEventStoragePath];
  // If only a target was given, return the target path.
  if (qosTier == nil && mappingID == nil) {
    return [NSString stringWithFormat:@"%@/%ld", baseEventPath, (long)target];
  }

  // If only a target and mappingID were given, return the mapping ID path.
  if (qosTier == nil) {
    return [NSString stringWithFormat:@"%@/%ld/%@", baseEventPath, (long)target, mappingID];
  }

  // If only a target and qosTier were given, return the QoS tier path.
  if (mappingID == nil) {
    return [NSString stringWithFormat:@"%@/%ld/%@", baseEventPath, (long)target, qosTier];
  }

  // If a target, mappingID, and qosTier were all given, return a single target/qosTier/mappingID
  // directory.
  return
      [NSString stringWithFormat:@"%@/%ld/%@/%@", baseEventPath, (long)target, qosTier, mappingID];
}

+ (NSArray<NSString *> *)searchPathsWithEventSelector:(GDTCORStorageEventSelector *)eventSelector {
  NSMutableArray<NSString *> *searchPaths = [[NSMutableArray alloc] init];
  if (eventSelector.selectedQosTiers && eventSelector.selectedQosTiers.count > 0) {
    for (NSNumber *qosTier in eventSelector.selectedQosTiers) {
      NSString *searchPath = [self pathForTarget:eventSelector.selectedTarget
                                         qosTier:qosTier
                                       mappingID:eventSelector.selectedMappingID];
      BOOL isDirectory;
      if ([[NSFileManager defaultManager] fileExistsAtPath:searchPath isDirectory:&isDirectory]) {
        if (isDirectory) {
          [searchPaths addObject:searchPath];
        }
      }
    }
  } else {
    NSString *searchPath = [self pathForTarget:eventSelector.selectedTarget
                                       qosTier:nil
                                     mappingID:eventSelector.selectedMappingID];
    BOOL isDirectory;
    if ([[NSFileManager defaultManager] fileExistsAtPath:searchPath isDirectory:&isDirectory]) {
      if (isDirectory) {
        [searchPaths addObject:searchPath];
      }
    }
  }
  return searchPaths;
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

- (void)storeEvent:(GDTCOREvent *)event
        onComplete:(void (^_Nullable)(BOOL wasWritten, NSError *_Nullable error))completion {
  GDTCORLogDebug(@"Saving event: %@", event);
  if (event == nil) {
    GDTCORLogDebug(@"%@", @"The event was nil, so it was not saved.");
    return;
  }
  BOOL hadOriginalCompletion = completion != nil;
  if (!completion) {
    completion = ^(BOOL wasWritten, NSError *_Nullable error) {
      GDTCORLogDebug(@"event %@ stored. success:%@ error:%@", event, wasWritten ? @"YES" : @"NO",
                     error);
    };
  }

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
      completion(NO, error);
      return;
    } else {
      GDTCORLogDebug(@"Event saved to disk: %@", eventFile);
      completion(YES, error);
    }

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
        GDTCORLogDebug(@"%@",
                       @"Saving flat file storage state because a completion block was passed.");
      } else {
        GDTCORLogDebug(
            @"%@", @"Saving flat file storage state because the app is running in the background");
      }
      NSError *error;
      GDTCOREncodeArchive(self, [GDTCORFlatFileStorage archivePath], &error);
      if (error) {
        GDTCORLogDebug(@"Serializing GDTCORFlatFileStorage to an archive failed: %@", error);
      }
    }

    // Cancel or end the associated background task if it's still valid.
    [[GDTCORApplication sharedApplication] endBackgroundTask:bgID];
    bgID = GDTCORBackgroundIdentifierInvalid;
    GDTCORLogDebug(@"Event %@ is stored. There are %ld events stored on disk", event,
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
          BOOL result = [[NSFileManager defaultManager] removeItemAtPath:fileURL.path error:&error];
          if (!result || error) {
            GDTCORLogWarning(GDTCORMCWFileReadError,
                             @"There was an error removing an event file: %@", error);
          } else {
            GDTCORLogDebug(@"Removed event from disk: %@", fileURL);
          }
        }

        // Remove from the tracking collections.
        [self.storedEvents removeObjectForKey:event.eventID];
        [self.targetToEventSet[@(event.target)] removeObject:event];
      }
    }
  });
}

#pragma mark - GDTCORStorageProtocol

- (void)libraryDataForKey:(nonnull NSString *)key
               onComplete:
                   (nonnull void (^)(NSData *_Nullable, NSError *_Nullable error))onComplete {
  dispatch_async(_storageQueue, ^{
    NSString *dataPath = [[[self class] libraryDataStoragePath] stringByAppendingPathComponent:key];
    NSError *error;
    NSData *data = [NSData dataWithContentsOfFile:dataPath options:0 error:&error];
    if (onComplete) {
      onComplete(data, error);
    }
  });
}

- (void)storeLibraryData:(NSData *)data
                  forKey:(nonnull NSString *)key
              onComplete:(nonnull void (^)(NSError *_Nullable error))onComplete {
  if (!data || data.length <= 0) {
    if (onComplete) {
      onComplete([NSError errorWithDomain:NSInternalInconsistencyException code:-1 userInfo:nil]);
    }
    return;
  }
  dispatch_async(_storageQueue, ^{
    NSError *error;
    NSString *dataPath = [[[self class] libraryDataStoragePath] stringByAppendingPathComponent:key];
    [data writeToFile:dataPath options:NSDataWritingAtomic error:&error];
    if (onComplete) {
      onComplete(error);
    }
  });
}

- (void)removeLibraryDataForKey:(nonnull NSString *)key
                     onComplete:(nonnull void (^)(NSError *_Nullable error))onComplete {
  dispatch_async(_storageQueue, ^{
    NSError *error;
    NSString *dataPath = [[[self class] libraryDataStoragePath] stringByAppendingPathComponent:key];
    if ([[NSFileManager defaultManager] fileExistsAtPath:dataPath]) {
      [[NSFileManager defaultManager] removeItemAtPath:dataPath error:&error];
      if (onComplete) {
        onComplete(error);
      }
    }
  });
}

- (BOOL)hasEventsForTarget:(GDTCORTarget)target {
  NSString *searchPath = [GDTCORFlatFileStorage pathForTarget:target qosTier:nil mappingID:nil];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:searchPath];
  NSString *nextFile;
  while ((nextFile = [enumerator nextObject])) {
    if ([enumerator.fileAttributes[NSFileType] isEqual:NSFileTypeDirectory] == NO &&
        [enumerator.fileAttributes[NSFileType] isEqual:NSFileTypeSymbolicLink] == NO) {
      return YES;
    }
  }
  return NO;
}

- (nullable id<GDTCORStorageEventIterator>)iteratorWithSelector:
    (nonnull GDTCORStorageEventSelector *)eventSelector {
  __block GDTCORFlatFileStorageIterator *iterator;
  dispatch_sync(_storageQueue, ^{
    NSMutableArray<NSString *> *filePaths;
    NSArray<NSString *> *searchPaths =
        [GDTCORFlatFileStorage searchPathsWithEventSelector:eventSelector];
    for (NSString *searchPath in searchPaths) {
      NSDirectoryEnumerator *enumerator =
          [[NSFileManager defaultManager] enumeratorAtPath:searchPath];
      NSString *nextFile;
      while ((nextFile = [enumerator nextObject])) {
        NSFileAttributeType fileType = enumerator.fileAttributes[NSFileType];
        if ([fileType isEqual:NSFileTypeDirectory] == NO &&
            [fileType isEqual:NSFileTypeSymbolicLink] == NO) {
          [filePaths addObject:nextFile];
        }
      }
      iterator = [[GDTCORFlatFileStorageIterator alloc] initWithTarget:eventSelector.selectedTarget
                                                                 queue:_storageQueue];
      iterator.eventFiles = filePaths;
    }
  });
  return iterator;
}

- (void)purgeEventsFromBefore:(GDTCORClock *)beforeSnapshot
                   onComplete:(void (^)(NSError *_Nullable error))onComplete {
  // TODO(mikehaney24): Figure out how we're going to deal with an NS
}

- (void)storageSizeWithCallback:(void (^)(uint64_t storageSize))onComplete {
  dispatch_async(_storageQueue, ^{
    unsigned long long totalBytes = 0;
    NSString *eventDataPath = [GDTCORFlatFileStorage baseEventStoragePath];
    NSString *libraryDataPath = [GDTCORFlatFileStorage libraryDataStoragePath];
    NSDirectoryEnumerator *enumerator =
        [[NSFileManager defaultManager] enumeratorAtPath:eventDataPath];
    while ([enumerator nextObject]) {
      NSFileAttributeType fileType = enumerator.fileAttributes[NSFileType];
      if ([fileType isEqual:NSFileTypeDirectory] == NO &&
          [fileType isEqual:NSFileTypeSymbolicLink] == NO) {
        NSNumber *fileSize = enumerator.fileAttributes[NSFileSize];
        totalBytes += fileSize.unsignedLongLongValue;
      }
    }
    enumerator = [[NSFileManager defaultManager] enumeratorAtPath:libraryDataPath];
    while ([enumerator nextObject]) {
      NSFileAttributeType fileType = enumerator.fileAttributes[NSFileType];
      if ([fileType isEqual:NSFileTypeDirectory] == NO &&
          [fileType isEqual:NSFileTypeSymbolicLink] == NO) {
        NSNumber *fileSize = enumerator.fileAttributes[NSFileSize];
        totalBytes += fileSize.unsignedLongLongValue;
      }
    }
    if (onComplete) {
      onComplete(totalBytes);
    }
  });
}

#pragma mark - Private helper methods

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
    NSError *error;
    GDTCORDecodeArchive([GDTCORFlatFileStorage class], [GDTCORFlatFileStorage archivePath], nil,
                        &error);
    if (error) {
      GDTCORLogDebug(@"Deserializing GDTCORFlatFileStorage from an archive failed: %@", error);
    }
  });
}

- (void)appWillBackground:(GDTCORApplication *)app {
  dispatch_async(_storageQueue, ^{
    // Immediately request a background task to run until the end of the current queue of work,
    // and cancel it once the work is done.
    __block GDTCORBackgroundIdentifier bgID =
        [app beginBackgroundTaskWithName:@"GDTStorage"
                       expirationHandler:^{
                         [app endBackgroundTask:bgID];
                         bgID = GDTCORBackgroundIdentifierInvalid;
                       }];
    NSError *error;
    GDTCOREncodeArchive(self, [GDTCORFlatFileStorage archivePath], &error);
    if (error) {
      GDTCORLogDebug(@"Serializing GDTCORFlatFileStorage to an archive failed: %@", error);
    } else {
      GDTCORLogDebug(@"Serialized GDTCORFlatFileStorage to %@",
                     [GDTCORFlatFileStorage archivePath]);
    }

    // End the background task if it's still valid.
    [app endBackgroundTask:bgID];
    bgID = GDTCORBackgroundIdentifierInvalid;
  });
}

- (void)appWillTerminate:(GDTCORApplication *)application {
  dispatch_sync(_storageQueue, ^{
    NSError *error;
    GDTCOREncodeArchive(self, [GDTCORFlatFileStorage archivePath], &error);
    if (error) {
      GDTCORLogDebug(@"Serializing GDTCORFlatFileStorage to an archive failed: %@", error);
    } else {
      GDTCORLogDebug(@"Serialized GDTCORFlatFileStorage to %@",
                     [GDTCORFlatFileStorage archivePath]);
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
