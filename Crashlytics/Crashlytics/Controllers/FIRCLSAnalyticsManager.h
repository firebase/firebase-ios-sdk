// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FIRCLSSettings;
@protocol FIRAnalyticsInterop;
@protocol FIRAnalyticsInteropListener;

/*
 * Registers a listener for Analytics events in Crashlytics
 * logs (aka. breadcrumbs), and sends events to the
 * Analytics SDK for Crash Free Users.
 */
@interface FIRCLSAnalyticsManager : NSObject

- (instancetype)initWithAnalytics:(nullable id<FIRAnalyticsInterop>)analytics;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/*
 * Starts listening for Analytics events for Breadcrumbs.
 */
- (void)registerAnalyticsListener;

/*
 * Logs a Crashlytics crash session to Firebase Analytics for Crash Free Users.
 * @param crashTimeStamp The time stamp of the crash to be logged.
 */
+ (void)logCrashWithTimeStamp:(NSTimeInterval)crashTimeStamp
                  toAnalytics:(id<FIRAnalyticsInterop>)analytics;

/*
 * Public for testing.
 */
NSString *FIRCLSFIRAEventDictionaryToJSON(NSDictionary *eventAsDictionary);

@end

NS_ASSUME_NONNULL_END
