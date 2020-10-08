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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseInAppMessaging/Sources/FIRCore+InAppMessaging.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMBookKeeper.h"

NSString *const FIRIAM_UserDefaultsKeyForImpressions = @"firebase-iam-message-impressions";
NSString *const FIRIAM_UserDefaultsKeyForLastImpressionTimestamp =
    @"firebase-iam-last-impression-timestamp";
NSString *FIRIAM_UserDefaultsKeyForLastFetchTimestamp = @"firebase-iam-last-fetch-timestamp";

// The two keys used to map FIRIAMImpressionRecord object to a NSDictionary object for
// persistence.
NSString *const FIRIAM_ImpressionDictKeyForID = @"message_id";
NSString *const FIRIAM_ImpressionDictKeyForTimestamp = @"impression_time";

static NSString *const kUserDefaultsKeyForFetchWaitTime = @"firebase-iam-fetch-wait-time";

// 24 hours
static NSTimeInterval kDefaultFetchWaitTimeInSeconds = 24 * 60 * 60;

// 3 days
static NSTimeInterval kMaxFetchWaitTimeInSeconds = 3 * 24 * 60 * 60;

@interface FIRIAMBookKeeperViaUserDefaults ()
@property(nonatomic) double lastDisplayTime;
@property(nonatomic) double lastFetchTime;
@property(nonatomic) double nextFetchWaitTime;
@property(nonatomic, nonnull) NSUserDefaults *defaults;
@end

@interface FIRIAMImpressionRecord ()
- (instancetype)initWithStorageDictionary:(NSDictionary *)dict;
@end

@implementation FIRIAMImpressionRecord

- (instancetype)initWithMessageID:(NSString *)messageID
          impressionTimeInSeconds:(long)impressionTime {
  if (self = [super init]) {
    _messageID = messageID;
    _impressionTimeInSeconds = impressionTime;
  }
  return self;
}

- (instancetype)initWithStorageDictionary:(NSDictionary *)dict {
  id timestamp = dict[FIRIAM_ImpressionDictKeyForTimestamp];
  id messageID = dict[FIRIAM_ImpressionDictKeyForID];

  if (![timestamp isKindOfClass:[NSNumber class]] || ![messageID isKindOfClass:[NSString class]]) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM270003",
                @"Incorrect data in the dictionary object for creating a FIRIAMImpressionRecord"
                 " object");
    return nil;
  } else {
    return [self initWithMessageID:messageID
           impressionTimeInSeconds:((NSNumber *)timestamp).longValue];
  }
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@ impressed at %ld in seconds", self.messageID,
                                    self.impressionTimeInSeconds];
}
@end

@implementation FIRIAMBookKeeperViaUserDefaults

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults {
  if (self = [super init]) {
    _defaults = userDefaults;

    // ok if it returns 0 due to the entry being absent
    _lastDisplayTime = [_defaults doubleForKey:FIRIAM_UserDefaultsKeyForLastImpressionTimestamp];
    _lastFetchTime = [_defaults doubleForKey:FIRIAM_UserDefaultsKeyForLastFetchTimestamp];

    id fetchWaitTimeEntry = [_defaults objectForKey:kUserDefaultsKeyForFetchWaitTime];

    if (![fetchWaitTimeEntry isKindOfClass:NSNumber.class]) {
      // This corresponds to the case there is no wait time entry is set in user defaults yet
      _nextFetchWaitTime = kDefaultFetchWaitTimeInSeconds;
    } else {
      _nextFetchWaitTime = ((NSNumber *)fetchWaitTimeEntry).doubleValue;
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM270009",
                  @"Next fetch wait time loaded from user defaults is %lf", _nextFetchWaitTime);
    }
  }
  return self;
}

// A helper function for reading and verifying the stored array data for impressions
// in UserDefaults. It returns nil if it does not exist or fail to pass the data type
// checking.
- (NSArray *)fetchImpressionArrayFromStorage {
  id impressionsData = [self.defaults objectForKey:FIRIAM_UserDefaultsKeyForImpressions];

  if (impressionsData && ![impressionsData isKindOfClass:[NSArray class]]) {
    FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM270007",
                  @"Found non-array data from impression userdefaults storage with key %@",
                  FIRIAM_UserDefaultsKeyForImpressions);
    return nil;
  }
  return (NSArray *)impressionsData;
}

- (void)recordNewImpressionForMessage:(NSString *)messageID
          withStartTimestampInSeconds:(double)timestamp {
  @synchronized(self) {
    NSArray *oldImpressions = [self fetchImpressionArrayFromStorage];
    // oldImpressions could be nil at the first time
    NSMutableArray *newImpressions =
        oldImpressions ? [oldImpressions mutableCopy] : [[NSMutableArray alloc] init];

    // Two cases
    //    If a prior impression exists for that messageID, update its impression timestamp
    //    If a prior impression for that messageID does not exist, add a new entry for the
    //    messageID.

    NSDictionary *newImpressionEntry = @{
      FIRIAM_ImpressionDictKeyForID : messageID,
      FIRIAM_ImpressionDictKeyForTimestamp : [NSNumber numberWithDouble:timestamp]
    };

    BOOL oldImpressionRecordFound = NO;

    for (int i = 0; i < newImpressions.count; i++) {
      if ([newImpressions[i] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *currentItem = (NSDictionary *)newImpressions[i];
        if ([messageID isEqualToString:currentItem[FIRIAM_ImpressionDictKeyForID]]) {
          FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM270001",
                      @"Updating timestamp of existing impression record to be %f for "
                       "message %@",
                      timestamp, messageID);

          [newImpressions replaceObjectAtIndex:i withObject:newImpressionEntry];
          oldImpressionRecordFound = YES;
          break;
        }
      }
    }

    if (!oldImpressionRecordFound) {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM270002",
                  @"Insert the first impression record for message %@ with timestamp in seconds "
                   "as %f",
                  messageID, timestamp);
      [newImpressions addObject:newImpressionEntry];
    }

    [self.defaults setObject:newImpressions forKey:FIRIAM_UserDefaultsKeyForImpressions];
    [self.defaults setDouble:timestamp forKey:FIRIAM_UserDefaultsKeyForLastImpressionTimestamp];
    self.lastDisplayTime = timestamp;
  }
}

- (void)clearImpressionsWithMessageList:(NSArray<NSString *> *)messageList {
  @synchronized(self) {
    NSArray *existingImpressions = [self fetchImpressionArrayFromStorage];

    NSSet<NSString *> *messageIDSet = [NSSet setWithArray:messageList];
    NSPredicate *notInMessageListPredicate =
        [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
          if (![evaluatedObject isKindOfClass:[NSDictionary class]]) {
            return NO;  // unexpected item. Throw it away
          }
          NSDictionary *impression = (NSDictionary *)evaluatedObject;
          return impression[FIRIAM_ImpressionDictKeyForID] &&
                 ![messageIDSet containsObject:impression[FIRIAM_ImpressionDictKeyForID]];
        }];

    NSArray<NSDictionary *> *updatedImpressions =
        [existingImpressions filteredArrayUsingPredicate:notInMessageListPredicate];

    if (existingImpressions.count != updatedImpressions.count) {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM270004",
                  @"Updating the impression records after purging %d items based on the "
                   "server fetch response",
                  (int)(existingImpressions.count - updatedImpressions.count));
      [self.defaults setObject:updatedImpressions forKey:FIRIAM_UserDefaultsKeyForImpressions];
    } else {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM270005",
                  @"No impression records update due to no change after applying the server "
                   "message list");
    }
  }
}

- (NSArray<FIRIAMImpressionRecord *> *)getImpressions {
  NSArray<NSDictionary *> *impressionsFromStorage = [self fetchImpressionArrayFromStorage];

  NSMutableArray<FIRIAMImpressionRecord *> *resultArray = [[NSMutableArray alloc] init];

  for (NSDictionary *next in impressionsFromStorage) {
    FIRIAMImpressionRecord *nextImpression =
        [[FIRIAMImpressionRecord alloc] initWithStorageDictionary:next];
    [resultArray addObject:nextImpression];
  }

  return resultArray;
}

- (NSArray<NSString *> *)getMessageIDsFromImpressions {
  NSArray<NSDictionary *> *impressionsFromStorage = [self fetchImpressionArrayFromStorage];

  NSMutableArray<NSString *> *resultArray = [[NSMutableArray alloc] init];

  for (NSDictionary *next in impressionsFromStorage) {
    [resultArray addObject:next[FIRIAM_ImpressionDictKeyForID]];
  }

  return resultArray;
}

- (void)recordNewFetchWithFetchCount:(NSInteger)fetchedMsgCount
              withTimestampInSeconds:(double)fetchTimestamp
                   nextFetchWaitTime:(nullable NSNumber *)nextFetchWaitTime;
{
  [self.defaults setDouble:fetchTimestamp forKey:FIRIAM_UserDefaultsKeyForLastFetchTimestamp];
  self.lastFetchTime = fetchTimestamp;

  if (nextFetchWaitTime != nil) {
    if (nextFetchWaitTime.doubleValue > kMaxFetchWaitTimeInSeconds) {
      FIRLogInfo(kFIRLoggerInAppMessaging, @"I-IAM270006",
                 @"next fetch wait time %lf is too large. Ignore it.",
                 nextFetchWaitTime.doubleValue);
    } else {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM270008",
                  @"Setting next fetch wait time as %lf from fetch response.",
                  nextFetchWaitTime.doubleValue);
      self.nextFetchWaitTime = nextFetchWaitTime.doubleValue;
      [self.defaults setObject:nextFetchWaitTime forKey:kUserDefaultsKeyForFetchWaitTime];
    }
  }
}

- (void)cleanupImpressions {
  [self.defaults setObject:@[] forKey:FIRIAM_UserDefaultsKeyForImpressions];
}

- (void)cleanupFetchRecords {
  [self.defaults setDouble:0 forKey:FIRIAM_UserDefaultsKeyForLastFetchTimestamp];
  self.lastFetchTime = 0;
}
@end

#endif  // TARGET_OS_IOS
