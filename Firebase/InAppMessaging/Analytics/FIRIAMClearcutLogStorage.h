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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface FIRIAMClearcutLogRecord : NSObject <NSSecureCoding>
@property(nonatomic, copy, readonly) NSString *eventExtensionJsonString;
@property(nonatomic, readonly) NSInteger eventTimestampInSeconds;
- (instancetype)initWithExtensionJsonString:(NSString *)jsonString
                    eventTimestampInSeconds:(NSInteger)eventTimestampInSeconds;
@end

@protocol FIRIAMTimeFetcher;

// A local persistent storage for saving FIRIAMClearcutLogRecord objects
// so that they can be delivered to clearcut server.
// Based on the clearcut log structure, our strategy is to store the json string
// for the source extension since it does not need to be modified upon delivery retries.
// The envelope of the clearcut log will be reconstructed when delivery is
// attempted.

@interface FIRIAMClearcutLogStorage : NSObject
- (instancetype)initWithExpireAfterInSeconds:(NSInteger)expireInSeconds
                             withTimeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher
                                   cachePath:(nullable NSString *)cachePath;

- (instancetype)initWithExpireAfterInSeconds:(NSInteger)expireInSeconds
                             withTimeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher;

// add new records into the storage
- (void)pushRecords:(NSArray<FIRIAMClearcutLogRecord *> *)newRecords;

// pop all the records that have not expired yet. With this call, these
// records are removed from the book of this local storage object.
// @param upTo the cap on how many records to be popped.
- (NSArray<FIRIAMClearcutLogRecord *> *)popStillValidRecordsForUpTo:(NSInteger)upTo;
@end
NS_ASSUME_NONNULL_END
