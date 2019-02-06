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

@class FIRIAMClearcutLogger;
@protocol FIRIAMTimeFetcher;
@protocol FIRAnalyticsInterop;

NS_ASSUME_NONNULL_BEGIN
/**
 * Implementation of protocol FIRIAMAnalyticsEventLogger by doing two things
 *  1 Firing Firebase Analytics Events for impressions and clicks and dismisses
 *  2 Making clearcut logging for all other types of analytics events
 */
@interface FIRIAMAnalyticsEventLoggerImpl : NSObject <FIRIAMAnalyticsEventLogger>
- (instancetype)init NS_UNAVAILABLE;

/**
 *
 *  @param userDefaults needed for tracking upload timing info persistently.If nil, using
 *    NSUserDefaults standardUserDefaults. It's defined as a parameter to help with
 *    unit testing mocking
 */
- (instancetype)initWithClearcutLogger:(FIRIAMClearcutLogger *)ctLogger
                      usingTimeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher
                     usingUserDefaults:(nullable NSUserDefaults *)userDefaults
                             analytics:(nullable id<FIRAnalyticsInterop>)analytics;
@end
NS_ASSUME_NONNULL_END
