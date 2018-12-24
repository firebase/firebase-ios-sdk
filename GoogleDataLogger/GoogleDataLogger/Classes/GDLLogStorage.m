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

#import "GDLConsoleLogger.h"
#import "GDLLogEvent_Private.h"
#import "GDLRegistrar_Private.h"
#import "GDLUploader.h"

/** */
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
    _logTargetToLogFileSet = [[NSMutableDictionary alloc] init];
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
    NSAssert(logPrioritizer, @"There's no scorer registered for the given logTarget.");

    // Write the extension bytes to disk, get a filename.
    NSAssert(shortLivedLog.extensionBytes, @"The log should have been serialized to bytes");
    NSAssert(shortLivedLog.extension == nil, @"The original log proto should be removed");
    NSURL *logFile =
        [self saveLogProtoToDisk:shortLivedLog.extensionBytes logHash:shortLivedLog.hash];

    // Add log to tracking collections.
    [self addLogToTrackingCollections:shortLivedLog logFile:logFile];

    // Check the QoS, if it's high priority, notify the log target that it has a high priority log.
    if (shortLivedLog.qosTier == GDLLogQoSFast) {
      NSSet<NSURL *> *allLogsForLogTarget = self.logTargetToLogFileSet[@(logTarget)];
      [[GDLUploader sharedInstance] forceUploadLogs:allLogsForLogTarget target:logTarget];
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

- (void)removeLog:(NSNumber *)logHash logTarget:(NSNumber *)logTarget {
  dispatch_async(_storageQueue, ^{
    NSURL *logFile = self.logHashToLogFile[logHash];

    // Remove from disk, first and foremost.
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtURL:logFile error:&error];
    NSAssert(error == nil, @"There was an error removing a logFile: %@", error);

    // Remove from the tracking collections.
    [self.logHashToLogFile removeObjectForKey:logHash];
    NSMutableSet<NSURL *> *logFiles = self.logTargetToLogFileSet[logTarget];
    NSAssert(logFiles, @"There wasn't a logSet for this logTarget.");
    [logFiles removeObject:logFile];
    // It's fine to not remove the set if it's empty.
  });
}

#pragma mark - Private helper methods

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
  NSString *logFile = [NSString stringWithFormat:@"log-%ld", logHash];
  NSURL *logFilePath = [NSURL fileURLWithPath:[storagePath stringByAppendingPathComponent:logFile]];

  BOOL writingSuccess = [logProtoBytes writeToURL:logFilePath atomically:YES];
  NSAssert(writingSuccess, @"A log file could not be written: %@", logFilePath);

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
  self.logHashToLogFile[@(log.hash)] = logFile;
  NSMutableSet<NSURL *> *logs = self.logTargetToLogFileSet[@(logTarget)];
  if (logs) {
    [logs addObject:logFile];
  } else {
    NSMutableSet<NSURL *> *logSet = [NSMutableSet setWithObject:logFile];
    self.logTargetToLogFileSet[@(logTarget)] = logSet;
  }
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  // TODO
  return [self.class sharedInstance];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  // TODO
}

@end
