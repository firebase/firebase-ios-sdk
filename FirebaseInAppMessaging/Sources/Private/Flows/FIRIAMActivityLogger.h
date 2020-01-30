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

/// Values for different fiam activity types.
typedef NS_ENUM(NSInteger, FIRIAMActivityType) {
  FIRIAMActivityTypeFetchMessage = 0,
  FIRIAMActivityTypeRenderMessage = 1,
  FIRIAMActivityTypeDismissMessage = 2,

  // Triggered checks
  FIRIAMActivityTypeCheckForOnOpenMessage = 3,
  FIRIAMActivityTypeCheckForAnalyticsEventMessage = 4,
  FIRIAMActivityTypeCheckForFetch = 5,
};

NS_ASSUME_NONNULL_BEGIN
@interface FIRIAMActivityRecord : NSObject <NSCoding>
@property(nonatomic, nonnull, readonly) NSDate *timestamp;
@property(nonatomic, readonly) FIRIAMActivityType activityType;
@property(nonatomic, readonly) BOOL success;
@property(nonatomic, copy, nonnull, readonly) NSString *detail;

- (instancetype)init NS_UNAVAILABLE;
// Current timestamp would be fetched if parameter 'timestamp' is passed in as null
- (instancetype)initWithActivityType:(FIRIAMActivityType)type
                        isSuccessful:(BOOL)isSuccessful
                          withDetail:(NSString *)detail
                           timestamp:(nullable NSDate *)timestamp;

- (NSString *)displayStringForActivityType;
@end

/**
 * This is the class for tracking fiam flow related activity logs. Its content can later on be
 * retrieved for debugging/reporting purpose.
 */
@interface FIRIAMActivityLogger : NSObject

// If it's NO, activity logs of certain types won't get recorded by Logger. Consult
// isMandatoryType implementation to tell what are the types belong to verbose mode
// Turn it on for debugging cases
@property(nonatomic, readonly) BOOL verboseMode;

- (instancetype)init NS_UNAVAILABLE;

/**
 * Parameter maxBeforeReduce and sizeAfterReduce defines the shrinking behavior when we reach
 * the size cap of log storage: when we see the number of log records goes beyond
 * maxBeforeReduce, we would trigger a reduction action which would bring the array length to be
 * the size as defined by sizeAfterReduce
 *
 * @param verboseMode see the comments for the verboseMode property
 * @param loadFromCache loads from cache to initialize the log list if it's true. Be aware that
 *     in this case, you should not call this method in main thread since reading the cache file
 *     can take time.
 */
- (instancetype)initWithMaxCountBeforeReduce:(NSInteger)maxBeforeReduce
                         withSizeAfterReduce:(NSInteger)sizeAfterReduce
                                 verboseMode:(BOOL)verboseMode
                               loadFromCache:(BOOL)loadFromCache;

/**
 * Inserting a new record into activity log.
 *
 * @param newRecord new record to be inserted
 */
- (void)addLogRecord:(FIRIAMActivityRecord *)newRecord;

/**
 * Get a immutable copy of the existing activity log records.
 */
- (NSArray<FIRIAMActivityRecord *> *)readRecords;
@end
NS_ASSUME_NONNULL_END
