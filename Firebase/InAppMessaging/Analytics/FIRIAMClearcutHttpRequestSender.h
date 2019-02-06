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
@protocol FIRIAMTimeFetcher;

NS_ASSUME_NONNULL_BEGIN
// class for sending requests to clearcut over its http API
@interface FIRIAMClearcutHttpRequestSender : NSObject

/**
 * Create an FIRIAMClearcutHttpRequestSender instance with specified clearcut server.
 *
 * @param serverHost API server host.
 * @param osMajorVersion detected iOS major version of the current device
 */
- (instancetype)initWithClearcutHost:(NSString *)serverHost
                    usingTimeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher
                  withOSMajorVersion:(NSString *)osMajorVersion;

/**
 * Sends a batch of FIRIAMClearcutLogRecord records to clearcut server.
 * @param logs an array of log records to be sent.
 * @param completion is the handler to triggered upon completion. 'success' is a bool
 *       to indicate if the sending is successful. 'shouldRetryLogs' indicates if these
 *       logs need to be retried later on. On success case, waitTimeInMills is the value
 *       returned from clearcut server to indicate the minimal wait time before another
 *       send request can be attempted.
 */

- (void)sendClearcutHttpRequestForLogs:(NSArray<FIRIAMClearcutLogRecord *> *)logs
                        withCompletion:(void (^)(BOOL success,
                                                 BOOL shouldRetryLogs,
                                                 int64_t waitTimeInMills))completion;
@end
NS_ASSUME_NONNULL_END
