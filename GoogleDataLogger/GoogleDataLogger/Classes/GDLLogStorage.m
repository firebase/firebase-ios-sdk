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

#import "GDLLogStorage.h"
#import "GDLLogStorage_Private.h"

#import <GoogleDataLogger/GDLLogPrioritizer.h>

#import "GDLAssert.h"
#import "GDLConsoleLogger.h"
#import "GDLLogEvent_Private.h"
#import "GDLRegistrar_Private.h"
#import "GDLUploadCoordinator.h"

/** Creates and/or returns a singleton NSString that is the shared logging path.
 *
 * @return The SDK logging path.
 */
static NSString *GDLStoragePath() {
  static NSString *archivePath;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSString *cachePath =
        NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    archivePath = [NSString stringWithFormat:@"%@/google-sdks-logs", cachePath];
  });
  return archivePath;
}

@implementation GDLLogStorage

+ (instancetype)sharedInstance {
  static GDLLogStorage *sharedStorage;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedStorage = [[GDLLogStorage alloc] init];
  });
  return sharedStorage;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _storageQueue = dispatch_queue_create("com.google.GDLLogStorage", DISPATCH_QUEUE_SERIAL);
    _logHashToLogFile = [[NSMutableDictionary alloc] init];
    _logTargetToLogHashSet = [[NSMutableDictionary alloc] init];
    _uploader = [GDLUploadCoordinator sharedInstance];
  }
  return self;
}

- (void)storeLog:(GDLLogEvent *)log {
  [self createLogDirectoryIfNotExists];

  // This is done to ensure that log is deallocated at the end of the ensuing block.
  __block GDLLogEvent *shortLivedLog = log;
  __weak GDLLogEvent *weakShortLivedLog = log;
  log = nil;

  dispatch_async(_storageQueue, ^{
    // Check that a backend implementation is available for this logTarget.
    NSInteger logTarget = shortLivedLog.logTarget;

    // Check that a log prioritizer is available for this logTarget.
    id<GDLLogPrioritizer> logPrioritizer =
        [GDLRegistrar sharedInstance].logTargetToPrioritizer[@(logTarget)];
    GDLAssert(logPrioritizer, @"There's no prioritizer registered for the given logTarget.");

    // Write the extension bytes to disk, get a filename.
    GDLAssert(shortLivedLog.extensionBytes, @"The log should have been serialized to bytes");
    NSURL *logFile = [self saveLogProtoToDisk:shortLivedLog.extensionBytes
                                      logHash:shortLivedLog.hash];

    // Add log to tracking collections.
    [self addLogToTrackingCollections:shortLivedLog logFile:logFile];

    // Check the QoS, if it's high priority, notify the log target that it has a high priority log.
    if (shortLivedLog.qosTier == GDLLogQoSFast) {
      NSSet<NSNumber *> *allLogsForLogTarget = self.logTargetToLogHashSet[@(logTarget)];
      [self.uploader forceUploadLogs:allLogsForLogTarget target:logTarget];
    }

    // Have the prioritizer prioritize the log, enforcing that they do not retain it.
    @autoreleasepool {
      [logPrioritizer prioritizeLog:shortLivedLog];
      shortLivedLog = nil;
    }
    if (weakShortLivedLog) {
      GDLLogError(GDLMCELogEventWasIllegallyRetained, @"%@",
                  @"A LogEvent should not be retained outside of storage.");
    };
  });
}

- (void)removeLogs:(NSSet<NSNumber *> *)logHashes logTarget:(NSNumber *)logTarget {
  dispatch_sync(_storageQueue, ^{
    for (NSNumber *logHash in logHashes) {
      [self removeLog:logHash logTarget:logTarget];
    }
  });
}

- (NSSet<NSURL *> *)logHashesToFiles:(NSSet<NSNumber *> *)logHashes {
  NSMutableSet<NSURL *> *logFiles = [[NSMutableSet alloc] init];
  dispatch_sync(_storageQueue, ^{
    for (NSNumber *hashNumber in logHashes) {
      NSURL *logURL = self.logHashToLogFile[hashNumber];
      GDLAssert(logURL, @"A log file URL couldn't be found for the given hash");
      [logFiles addObject:logURL];
    }
  });
  return logFiles;
}

#pragma mark - Private helper methods

/** Removes the corresponding log file from disk.
 *
 * @param logHash The hash value of the original log.
 * @param logTarget The logTarget of the original log.
 */
- (void)removeLog:(NSNumber *)logHash logTarget:(NSNumber *)logTarget {
  NSURL *logFile = self.logHashToLogFile[logHash];

  // Remove from disk, first and foremost.
  NSError *error;
  [[NSFileManager defaultManager] removeItemAtURL:logFile error:&error];
  GDLAssert(error == nil, @"There was an error removing a logFile: %@", error);

  // Remove from the tracking collections.
  [self.logHashToLogFile removeObjectForKey:logHash];
  NSMutableSet<NSNumber *> *logHashes = self.logTargetToLogHashSet[logTarget];
  GDLAssert(logHashes, @"There wasn't a logSet for this logTarget.");
  [logHashes removeObject:logHash];
  // It's fine to not remove the set if it's empty.

  // Check that a log prioritizer is available for this logTarget.
  id<GDLLogPrioritizer> logPrioritizer =
      [GDLRegistrar sharedInstance].logTargetToPrioritizer[logTarget];
  GDLAssert(logPrioritizer, @"There's no prioritizer registered for the given logTarget.");
  [logPrioritizer unprioritizeLog:logHash];
}

/** Creates the log directory if it does not exist. */
- (void)createLogDirectoryIfNotExists {
  NSError *error;
  BOOL result = [[NSFileManager defaultManager] createDirectoryAtPath:GDLStoragePath()
                                          withIntermediateDirectories:YES
                                                           attributes:0
                                                                error:&error];
  if (!result || error) {
    GDLLogError(GDLMCEDirectoryCreationError, @"Error creating the directory: %@", error);
  }
}

/** Saves the log's extensionBytes to a file using NSData mechanisms.
 *
 * @note This method should only be called from a method within a block on _storageQueue to maintain
 * thread safety.
 *
 * @param logProtoBytes The extensionBytes of the log, presumably proto bytes.
 * @param logHash The hash value of the log.
 * @return The filename
 */
- (NSURL *)saveLogProtoToDisk:(NSData *)logProtoBytes logHash:(NSUInteger)logHash {
  NSString *storagePath = GDLStoragePath();
  NSString *logFile = [NSString stringWithFormat:@"log-%lu", (unsigned long)logHash];
  NSURL *logFilePath = [NSURL fileURLWithPath:[storagePath stringByAppendingPathComponent:logFile]];

  BOOL writingSuccess = [logProtoBytes writeToURL:logFilePath atomically:YES];
  if (!writingSuccess) {
    GDLLogError(GDLMCEFileWriteError, @"A log file could not be written: %@", logFilePath);
  }

  return logFilePath;
}

/** Adds the log to internal collections in order to help track the log.
 *
 * @note This method should only be called from a method within a block on _storageQueue to maintain
 * thread safety.
 *
 * @param log The log to track.
 * @param logFile The file the log has been saved to.
 */
- (void)addLogToTrackingCollections:(GDLLogEvent *)log logFile:(NSURL *)logFile {
  NSInteger logTarget = log.logTarget;
  NSNumber *logHash = @(log.hash);
  NSNumber *logTargetNumber = @(logTarget);
  self.logHashToLogFile[logHash] = logFile;
  NSMutableSet<NSNumber *> *logs = self.logTargetToLogHashSet[logTargetNumber];
  if (logs) {
    [logs addObject:logHash];
  } else {
    NSMutableSet<NSNumber *> *logSet = [NSMutableSet setWithObject:logHash];
    self.logTargetToLogHashSet[logTargetNumber] = logSet;
  }
}

#pragma mark - NSSecureCoding

/** The NSKeyedCoder key for the logHashToFile property. */
static NSString *const kGDLLogHashToLogFileKey = @"logHashToLogFileKey";

/** The NSKeyedCoder key for the logTargetToLogHashSet property. */
static NSString *const kGDLLogTargetToLogHashSetKey = @"logTargetToLogHashSetKey";

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  // Create the singleton and populate its ivars.
  GDLLogStorage *sharedInstance = [self.class sharedInstance];
  dispatch_sync(sharedInstance.storageQueue, ^{
    Class NSMutableDictionaryClass = [NSMutableDictionary class];
    sharedInstance->_logHashToLogFile = [aDecoder decodeObjectOfClass:NSMutableDictionaryClass
                                                               forKey:kGDLLogHashToLogFileKey];
    sharedInstance->_logTargetToLogHashSet =
        [aDecoder decodeObjectOfClass:NSMutableDictionaryClass forKey:kGDLLogTargetToLogHashSetKey];
  });
  return sharedInstance;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  GDLLogStorage *sharedInstance = [self.class sharedInstance];
  dispatch_sync(sharedInstance.storageQueue, ^{
    [aCoder encodeObject:sharedInstance->_logHashToLogFile forKey:kGDLLogHashToLogFileKey];
    [aCoder encodeObject:sharedInstance->_logTargetToLogHashSet
                  forKey:kGDLLogTargetToLogHashSetKey];
  });
}

@end
