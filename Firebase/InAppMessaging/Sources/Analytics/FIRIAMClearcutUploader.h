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

@class FIRIAMClearcutLogRecord;
@class FIRIAMClearcutHttpRequestSender;
@class FIRIAMClearcutLogStorage;

@protocol FIRIAMTimeFetcher;

NS_ASSUME_NONNULL_BEGIN

// class for defining a number of configs to control clearcut upload behavior
@interface FIRIAMClearcutStrategy : NSObject

// minimalWaitTimeInMills and maximumWaitTimeInMills defines the bottom and
// upper bound of the wait time before next upload if prior upload attempt was
// successful. Clearcut may return a value to give the wait time guidance in
// the upload response, but we also use these two values for sanity check to avoid
// too crazy behavior if the guidance value from server does not make sense
@property(nonatomic, readonly) NSInteger minimalWaitTimeInMills;
@property(nonatomic, readonly) NSInteger maximumWaitTimeInMills;

// back off wait time in mills if a prior upload attempt fails
@property(nonatomic, readonly) NSInteger failureBackoffTimeInMills;

// the maximum number of log records to be sent in one upload attempt
@property(nonatomic, readonly) NSInteger batchSendSize;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithMinWaitTimeInMills:(NSInteger)minWaitTimeInMills
                        maxWaitTimeInMills:(NSInteger)maxWaitTimeInMills
                 failureBackoffTimeInMills:(NSInteger)failureBackoffTimeInMills
                             batchSendSize:(NSInteger)batchSendSize;

- (NSString *)description;
@end

// A class for accepting new clearcut logs and scheduling the uploading of the logs in batches
// based on defined strategies.
@interface FIRIAMClearcutUploader : NSObject
- (instancetype)init NS_UNAVAILABLE;

/**
 *
 * @param userDefaults needed for tracking upload timing info persistently.If nil, using
 * NSUserDefaults standardUserDefaults. It's defined as a parameter to help with
 * unit testing mocking
 */
- (instancetype)initWithRequestSender:(FIRIAMClearcutHttpRequestSender *)requestSender
                          timeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher
                           logStorage:(FIRIAMClearcutLogStorage *)retryStorage
                        usingStrategy:(FIRIAMClearcutStrategy *)strategy
                    usingUserDefaults:(nullable NSUserDefaults *)userDefaults;
/**
 * This should return very quickly without blocking on and actual log uploading to
 * clearcut server, which is done asynchronously
 */
- (void)addNewLogRecord:(FIRIAMClearcutLogRecord *)record;
@end
NS_ASSUME_NONNULL_END
