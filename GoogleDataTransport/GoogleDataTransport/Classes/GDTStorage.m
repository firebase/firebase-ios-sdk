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

#import "GDTAssert.h"
#import "GDTConsoleLogger.h"
#import "GDTEvent_Private.h"
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
    _eventHashToFile = [[NSMutableDictionary alloc] init];
    _targetToEventHashSet = [[NSMutableDictionary alloc] init];
    _uploader = [GDTUploadCoordinator sharedInstance];
  }
  return self;
}

- (void)storeEvent:(GDTEvent *)event {
  [self createEventDirectoryIfNotExists];

  // This is done to ensure that event is deallocated at the end of the ensuing block.
  __block GDTEvent *shortLivedEvent = event;
  __weak GDTEvent *weakShortLivedEvent = event;
  event = nil;

  dispatch_async(_storageQueue, ^{
    // Check that a backend implementation is available for this target.
    NSInteger target = shortLivedEvent.target;

    // Check that a prioritizer is available for this target.
    id<GDTPrioritizer> prioritizer = [GDTRegistrar sharedInstance].targetToPrioritizer[@(target)];
    GDTAssert(prioritizer, @"There's no prioritizer registered for the given target.");

    // Write the transport bytes to disk, get a filename.
    GDTAssert(shortLivedEvent.dataObjectTransportBytes,
              @"The event should have been serialized to bytes");
    NSURL *eventFile = [self saveEventBytesToDisk:shortLivedEvent.dataObjectTransportBytes
                                        eventHash:shortLivedEvent.hash];

    // Add event to tracking collections.
    [self addEventToTrackingCollections:shortLivedEvent eventFile:eventFile];

    // Check the QoS, if it's high priority, notify the target that it has a high priority event.
    if (shortLivedEvent.qosTier == GDTEventQoSFast) {
      NSSet<NSNumber *> *allEventsForTarget = self.targetToEventHashSet[@(target)];
      [self.uploader forceUploadEvents:allEventsForTarget target:target];
    }

    // Have the prioritizer prioritize the event, enforcing that they do not retain it.
    @autoreleasepool {
      [prioritizer prioritizeEvent:shortLivedEvent];
      shortLivedEvent = nil;
    }
    if (weakShortLivedEvent) {
      GDTLogError(GDTMCEEventWasIllegallyRetained, @"%@",
                  @"An event should not be retained outside of storage.");
    };
  });
}

- (void)removeEvents:(NSSet<NSNumber *> *)eventHashes target:(NSNumber *)target {
  dispatch_sync(_storageQueue, ^{
    for (NSNumber *eventHash in eventHashes) {
      [self removeEvent:eventHash target:target];
    }
  });
}

- (NSSet<NSURL *> *)eventHashesToFiles:(NSSet<NSNumber *> *)eventHashes {
  NSMutableSet<NSURL *> *eventFiles = [[NSMutableSet alloc] init];
  dispatch_sync(_storageQueue, ^{
    for (NSNumber *hashNumber in eventHashes) {
      NSURL *eventURL = self.eventHashToFile[hashNumber];
      GDTAssert(eventURL, @"An event file URL couldn't be found for the given hash");
      [eventFiles addObject:eventURL];
    }
  });
  return eventFiles;
}

#pragma mark - Private helper methods

/** Removes the corresponding event file from disk.
 *
 * @param eventHash The hash value of the original event.
 * @param target The target of the original event.
 */
- (void)removeEvent:(NSNumber *)eventHash target:(NSNumber *)target {
  NSURL *eventFile = self.eventHashToFile[eventHash];

  // Remove from disk, first and foremost.
  NSError *error;
  [[NSFileManager defaultManager] removeItemAtURL:eventFile error:&error];
  GDTAssert(error == nil, @"There was an error removing an event file: %@", error);

  // Remove from the tracking collections.
  [self.eventHashToFile removeObjectForKey:eventHash];
  NSMutableSet<NSNumber *> *eventHashes = self.targetToEventHashSet[target];
  GDTAssert(eventHashes, @"There wasn't an event set for this target.");
  [eventHashes removeObject:eventHash];
  // It's fine to not remove the set if it's empty.

  // Check that a prioritizer is available for this target.
  id<GDTPrioritizer> prioritizer = [GDTRegistrar sharedInstance].targetToPrioritizer[target];
  GDTAssert(prioritizer, @"There's no prioritizer registered for the given target.");
  [prioritizer unprioritizeEvent:eventHash];
}

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
 * @param eventFile The file the event has been saved to.
 */
- (void)addEventToTrackingCollections:(GDTEvent *)event eventFile:(NSURL *)eventFile {
  NSInteger target = event.target;
  NSNumber *eventHash = @(event.hash);
  NSNumber *targetNumber = @(target);
  self.eventHashToFile[eventHash] = eventFile;
  NSMutableSet<NSNumber *> *events = self.targetToEventHashSet[targetNumber];
  if (events) {
    [events addObject:eventHash];
  } else {
    NSMutableSet<NSNumber *> *eventSet = [NSMutableSet setWithObject:eventHash];
    self.targetToEventHashSet[targetNumber] = eventSet;
  }
}

#pragma mark - NSSecureCoding

/** The NSKeyedCoder key for the eventHashToFile property. */
static NSString *const kGDTEventHashToFileKey = @"eventHashToFileKey";

/** The NSKeyedCoder key for the targetToEventHashSet property. */
static NSString *const kGDTTargetToEventHashSetKey = @"targetToEventHashSetKey";

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  // Create the singleton and populate its ivars.
  GDTStorage *sharedInstance = [self.class sharedInstance];
  dispatch_sync(sharedInstance.storageQueue, ^{
    Class NSMutableDictionaryClass = [NSMutableDictionary class];
    sharedInstance->_eventHashToFile = [aDecoder decodeObjectOfClass:NSMutableDictionaryClass
                                                              forKey:kGDTEventHashToFileKey];
    sharedInstance->_targetToEventHashSet =
        [aDecoder decodeObjectOfClass:NSMutableDictionaryClass forKey:kGDTTargetToEventHashSetKey];
  });
  return sharedInstance;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  GDTStorage *sharedInstance = [self.class sharedInstance];
  dispatch_sync(sharedInstance.storageQueue, ^{
    [aCoder encodeObject:sharedInstance->_eventHashToFile forKey:kGDTEventHashToFileKey];
    [aCoder encodeObject:sharedInstance->_targetToEventHashSet forKey:kGDTTargetToEventHashSetKey];
  });
}

@end
