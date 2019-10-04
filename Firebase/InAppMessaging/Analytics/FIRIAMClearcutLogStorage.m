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

#import <UIKit/UIKit.h>

#import <FirebaseCore/FIRLogger.h>

#import "FIRCore+InAppMessaging.h"
#import "FIRIAMClearcutLogStorage.h"
#import "FIRIAMTimeFetcher.h"

@implementation FIRIAMClearcutLogRecord
static NSString *const kEventTimestampKey = @"event_ts_seconds";
static NSString *const kEventExtensionJson = @"extension_js";

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)initWithExtensionJsonString:(NSString *)jsonString
                    eventTimestampInSeconds:(NSInteger)eventTimestampInSeconds {
  self = [super init];
  if (self != nil) {
    _eventTimestampInSeconds = eventTimestampInSeconds;
    _eventExtensionJsonString = jsonString;
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
  self = [super init];
  if (self != nil) {
    _eventTimestampInSeconds = [decoder decodeIntegerForKey:kEventTimestampKey];
    _eventExtensionJsonString = [decoder decodeObjectOfClass:[NSString class]
                                                      forKey:kEventExtensionJson];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
  [encoder encodeInteger:self.eventTimestampInSeconds forKey:kEventTimestampKey];
  [encoder encodeObject:self.eventExtensionJsonString forKey:kEventExtensionJson];
}
@end

@interface FIRIAMClearcutLogStorage ()
@property(nonatomic) NSInteger recordExpiresInSeconds;
@property(nonatomic) NSMutableArray<FIRIAMClearcutLogRecord *> *records;
@property(nonatomic) id<FIRIAMTimeFetcher> timeFetcher;
@end

// We keep all the records in memory and flush them into files upon receiving
// applicationDidEnterBackground notifications.
@implementation FIRIAMClearcutLogStorage

+ (NSString *)determineCacheFilePath {
  static NSString *logCachePath;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    NSString *libraryDirPath =
        NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    logCachePath =
        [NSString stringWithFormat:@"%@/firebase-iam-clearcut-retry-records", libraryDirPath];
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM230001",
                @"Persistent file path for clearcut log records is %@", logCachePath);
  });
  return logCachePath;
}

- (instancetype)initWithExpireAfterInSeconds:(NSInteger)expireInSeconds
                             withTimeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher
                                   cachePath:(nullable NSString *)cachePath {
  if (self = [super init]) {
    _records = [[NSMutableArray alloc] init];
    _timeFetcher = timeFetcher;
    _recordExpiresInSeconds = expireInSeconds;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillBecomeInactive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    @try {
      [self loadFromCachePath:cachePath];
    } @catch (NSException *exception) {
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM230004",
                    @"Non-fatal exception in loading persisted clearcut log records: %@.",
                    exception);
    }
  }
  return self;
}

- (instancetype)initWithExpireAfterInSeconds:(NSInteger)expireInSeconds
                             withTimeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher {
  return [self initWithExpireAfterInSeconds:expireInSeconds
                            withTimeFetcher:timeFetcher
                                  cachePath:nil];
}

- (void)appWillBecomeInactive {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
    [self saveIntoCacheWithPath:nil];
  });
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)pushRecords:(NSArray<FIRIAMClearcutLogRecord *> *)newRecords {
  @synchronized(self) {
    [self.records addObjectsFromArray:newRecords];
  }
}

- (NSArray<FIRIAMClearcutLogRecord *> *)popStillValidRecordsForUpTo:(NSInteger)upTo {
  NSMutableArray<FIRIAMClearcutLogRecord *> *resultArray = [[NSMutableArray alloc] init];
  NSInteger nowInSeconds = (NSInteger)[self.timeFetcher currentTimestampInSeconds];

  NSInteger next = 0;

  @synchronized(self) {
    while (resultArray.count < upTo && next < self.records.count) {
      FIRIAMClearcutLogRecord *nextRecord = self.records[next++];
      if (nextRecord.eventTimestampInSeconds > nowInSeconds - self.recordExpiresInSeconds) {
        // record not expired yet
        [resultArray addObject:nextRecord];
      }
    }

    [self.records removeObjectsInRange:NSMakeRange(0, next)];
  }

  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM230005",
              @"Returning %d clearcut retry records from popStillValidRecords",
              (int)resultArray.count);
  return resultArray;
}

- (void)loadFromCachePath:(NSString *)cacheFilePath {
  NSString *filePath = cacheFilePath == nil ? [self.class determineCacheFilePath] : cacheFilePath;

  NSTimeInterval start = [self.timeFetcher currentTimestampInSeconds];
  id fetchedClearcutRetryRecords = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
  if (fetchedClearcutRetryRecords) {
    @synchronized(self) {
      self.records = (NSMutableArray<FIRIAMClearcutLogRecord *> *)fetchedClearcutRetryRecords;
    }
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM230002",
                @"Loaded %d clearcut log records from file in %lf seconds", (int)self.records.count,
                (double)[self.timeFetcher currentTimestampInSeconds] - start);
  }
}

- (BOOL)saveIntoCacheWithPath:(NSString *)cacheFilePath {
  NSString *filePath = cacheFilePath == nil ? [self.class determineCacheFilePath] : cacheFilePath;
  @synchronized(self) {
    BOOL saveResult = [NSKeyedArchiver archiveRootObject:self.records toFile:filePath];
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM230003",
                @"Saving %d clearcut log records into file is %@", (int)self.records.count,
                saveResult ? @"successful" : @"failure");

    return saveResult;
  }
}
@end
