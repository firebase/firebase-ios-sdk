/*
 * Copyright 2017 Google
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
#import "FIRIAMActivityLogger.h"
@implementation FIRIAMActivityRecord

static NSString *const kActiveTypeArchiveKey = @"type";
static NSString *const kIsSuccessArchiveKey = @"is_success";
static NSString *const kTimeStampArchiveKey = @"timestamp";
static NSString *const kDetailArchiveKey = @"detail";

- (id)initWithCoder:(NSCoder *)decoder {
  self = [super init];
  if (self != nil) {
    _activityType = [decoder decodeIntegerForKey:kActiveTypeArchiveKey];
    _timestamp = [decoder decodeObjectForKey:kTimeStampArchiveKey];
    _success = [decoder decodeBoolForKey:kIsSuccessArchiveKey];
    _detail = [decoder decodeObjectForKey:kDetailArchiveKey];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
  [encoder encodeInteger:self.activityType forKey:kActiveTypeArchiveKey];
  [encoder encodeObject:self.timestamp forKey:kTimeStampArchiveKey];
  [encoder encodeBool:self.success forKey:kIsSuccessArchiveKey];
  [encoder encodeObject:self.detail forKey:kDetailArchiveKey];
}

- (instancetype)initWithActivityType:(FIRIAMActivityType)type
                        isSuccessful:(BOOL)isSuccessful
                          withDetail:(NSString *)detail
                           timestamp:(nullable NSDate *)timestamp {
  if (self = [super init]) {
    _activityType = type;
    _success = isSuccessful;
    _detail = detail;
    _timestamp = timestamp ? timestamp : [[NSDate alloc] init];
  }
  return self;
}

- (NSString *)displayStringForActivityType {
  switch (self.activityType) {
    case FIRIAMActivityTypeFetchMessage:
      return @"Message Fetching";
    case FIRIAMActivityTypeRenderMessage:
      return @"Message Rendering";
    case FIRIAMActivityTypeDismissMessage:
      return @"Message Dismiss";
    case FIRIAMActivityTypeCheckForOnOpenMessage:
      return @"OnOpen Msg Check";
    case FIRIAMActivityTypeCheckForAnalyticsEventMessage:
      return @"Analytic Msg Check";
    case FIRIAMActivityTypeCheckForFetch:
      return @"Fetch Check";
  }
}
@end

@interface FIRIAMActivityLogger ()
@property(nonatomic) BOOL isDirty;

// always insert at the head of this array so that they are always in anti-chronological order
@property(nonatomic, nonnull) NSMutableArray<FIRIAMActivityRecord *> *activityRecords;

// When we see the number of log records goes beyond maxRecordCountBeforeReduce, we would trigger
// a reduction action which would bring the array length to be the size as defined by
// newSizeAfterReduce
@property(nonatomic, readonly) NSInteger maxRecordCountBeforeReduce;
@property(nonatomic, readonly) NSInteger newSizeAfterReduce;

@end

@implementation FIRIAMActivityLogger
- (instancetype)initWithMaxCountBeforeReduce:(NSInteger)maxBeforeReduce
                         withSizeAfterReduce:(NSInteger)sizeAfterReduce
                                 verboseMode:(BOOL)verboseMode
                               loadFromCache:(BOOL)loadFromCache {
  if (self = [super init]) {
    _maxRecordCountBeforeReduce = maxBeforeReduce;
    _newSizeAfterReduce = sizeAfterReduce;
    _activityRecords = [[NSMutableArray alloc] init];
    _verboseMode = verboseMode;
    _isDirty = NO;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillBecomeInactive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];

    if (loadFromCache) {
      @try {
        [self loadFromCachePath:nil];
      } @catch (NSException *exception) {
        FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM310003",
                      @"Non-fatal exception in loading persisted activity log records: %@.",
                      exception);
      }
    }
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (NSString *)determineCacheFilePath {
  static NSString *logCachePath;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    NSString *cacheDirPath =
        NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    logCachePath = [NSString stringWithFormat:@"%@/firebase-iam-activity-log-cache", cacheDirPath];
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM310001",
                @"Persistent file path for activity log data is %@", logCachePath);
  });
  return logCachePath;
}

- (void)loadFromCachePath:(NSString *)cacheFilePath {
  NSString *filePath = cacheFilePath == nil ? [self.class determineCacheFilePath] : cacheFilePath;

  id fetchedActivityRecords = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];

  if (fetchedActivityRecords) {
    @synchronized(self) {
      self.activityRecords = (NSMutableArray<FIRIAMActivityRecord *> *)fetchedActivityRecords;
      self.isDirty = NO;
    }
  }
}

- (BOOL)saveIntoCacheWithPath:(NSString *)cacheFilePath {
  NSString *filePath = cacheFilePath == nil ? [self.class determineCacheFilePath] : cacheFilePath;
  @synchronized(self) {
    BOOL result = [NSKeyedArchiver archiveRootObject:self.activityRecords toFile:filePath];
    if (result) {
      self.isDirty = NO;
    }
    return result;
  }
}

- (void)appWillBecomeInactive {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM310004",
              @"App will become inactive, save"
               " activity logs");

  if (self.isDirty) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
      if ([self saveIntoCacheWithPath:nil]) {
        FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM310002",
                    @"Persisting activity log data is was successful");
      } else {
        FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM310005",
                      @"Persisting activity log data has failed");
      }
    });
  }
}

// Helper function to determine if a given activity type should be recorded under
// non verbose type.
+ (BOOL)isMandatoryType:(FIRIAMActivityType)type {
  switch (type) {
    case FIRIAMActivityTypeFetchMessage:
    case FIRIAMActivityTypeRenderMessage:
    case FIRIAMActivityTypeDismissMessage:
      return YES;
    default:
      return NO;
  }
}

- (void)addLogRecord:(FIRIAMActivityRecord *)newRecord {
  if (self.verboseMode || [FIRIAMActivityLogger isMandatoryType:newRecord.activityType]) {
    @synchronized(self) {
      [self.activityRecords insertObject:newRecord atIndex:0];

      if (self.activityRecords.count >= self.maxRecordCountBeforeReduce) {
        NSRange removeRange;
        removeRange.location = self.newSizeAfterReduce;
        removeRange.length = self.maxRecordCountBeforeReduce - self.newSizeAfterReduce;
        [self.activityRecords removeObjectsInRange:removeRange];
      }
      self.isDirty = YES;
    }
  }
}

- (NSArray<FIRIAMActivityRecord *> *)readRecords {
  return [self.activityRecords copy];
}
@end
