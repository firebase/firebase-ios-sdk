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
#import "FIRIAMAnalyticsEventLogger.h"
#import "FIRIAMClientInfoFetcher.h"
#import "FIRIAMTimeFetcher.h"

@class FIRIAMClearcutUploader;

NS_ASSUME_NONNULL_BEGIN
// FIRIAMAnalyticsEventLogger implementation using Clearcut. It turns a IAM analytics event
// into the corresponding FIRIAMClearcutLogRecord and then hand it over to
// a FIRIAMClearcutUploader instance for the actual sending and potential failure and retry
// logic
@interface FIRIAMClearcutLogger : NSObject <FIRIAMAnalyticsEventLogger>

- (instancetype)init NS_UNAVAILABLE;

/**
 * Create an instance which uses NSURLSession to make clearcut api calls.
 *
 * @param clientInfoFetcher used to fetch iid info for the current app.
 * @param timeFetcher time fetcher object
 * @param uploader FIRIAMClearcutUploader object for receiving the log record
 */
- (instancetype)initWithFBProjectNumber:(NSString *)fbProjectNumber
                                fbAppId:(NSString *)fbAppId
                      clientInfoFetcher:(FIRIAMClientInfoFetcher *)clientInfoFetcher
                       usingTimeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher
                          usingUploader:(FIRIAMClearcutUploader *)uploader;
@end
NS_ASSUME_NONNULL_END
