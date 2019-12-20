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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface FIRIAMImpressionRecord : NSObject
@property(nonatomic, readonly, copy) NSString *messageID;
@property(nonatomic, readonly) long impressionTimeInSeconds;

- (NSString *)description;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithMessageID:(NSString *)messageID
          impressionTimeInSeconds:(long)impressionTime NS_DESIGNATED_INITIALIZER;
@end

// this protocol defines the interface for classes that can be used to track info regarding
// display & fetch of iam messages. The info tracked here can be used to decide if it's due for
// next display and/or fetch of iam messages.
@protocol FIRIAMBookKeeper
@property(nonatomic, readonly) double lastDisplayTime;
@property(nonatomic, readonly) double lastFetchTime;
@property(nonatomic, readonly) NSTimeInterval nextFetchWaitTime;

// only call this when it's considered to be a valid impression (for example, meeting the minimum
// display time requirement).
- (void)recordNewImpressionForMessage:(NSString *)messageID
          withStartTimestampInSeconds:(double)timestamp;

- (void)recordNewFetchWithFetchCount:(NSInteger)fetchedMsgCount
              withTimestampInSeconds:(double)fetchTimestamp
                   nextFetchWaitTime:(nullable NSNumber *)nextFetchWaitTime;

// When we fetch the eligible message list from the sdk server, it can contain messages that are
// already impressed for those that are defined to be displayed repeatedly (messages with custom
// display frequency). We need then clean up the impression records for these messages so that
// they can be displayed again on client side.
- (void)clearImpressionsWithMessageList:(NSArray<NSString *> *)messageList;
// fetch the impression list
- (NSArray<FIRIAMImpressionRecord *> *)getImpressions;

// For certain clients, they only need to get the list of the message ids in existing impression
// records. This is a helper method for that.
- (NSArray<NSString *> *)getMessageIDsFromImpressions;
@end

// implementation of FIRIAMBookKeeper protocol by storing data within iOS UserDefaults.
// TODO: switch to something else if there is risks for the data being unintentionally deleted by
// the app
@interface FIRIAMBookKeeperViaUserDefaults : NSObject <FIRIAMBookKeeper>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults NS_DESIGNATED_INITIALIZER;

// for testing, don't use them for production purpose
- (void)cleanupImpressions;
- (void)cleanupFetchRecords;

@end

NS_ASSUME_NONNULL_END
