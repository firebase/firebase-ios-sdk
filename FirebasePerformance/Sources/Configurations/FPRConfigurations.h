// Copyright 2020 Google LLC
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

/** A typedef for ensuring that config names are one of the below specified strings. */
typedef NSString* const FPRConfigName;

/**
 * Class that manages the configurations used by firebase performance SDK. This class abstracts the
 * configuration flags from different configuration sources.
 */
@interface FPRConfigurations : NSObject

/** Enables or disables performance data collection in the SDK. If the value is set to 'NO' none of
 * the performance data will be sent to the server. Default is YES. */
@property(nonatomic, getter=isDataCollectionEnabled) BOOL dataCollectionEnabled;

/** The config KVC name string for the dataCollectionEnabled property. */
FOUNDATION_EXTERN FPRConfigName kFPRConfigDataCollectionEnabled;

/** Enables or disables instrumenting the app to collect performance data (like app start time,
 * networking). Default is YES. */
@property(nonatomic, getter=isInstrumentationEnabled) BOOL instrumentationEnabled;

/** The config KVC name string for the instrumentationEnabled property. */
FOUNDATION_EXTERN FPRConfigName kFPRConfigInstrumentationEnabled;

/** Log source against which the Fireperf events are recorded. */
@property(nonatomic, readonly) int logSource;

/** Specifies if the SDK is enabled. */
@property(nonatomic, readonly) BOOL sdkEnabled;

/** Specifies if the diagnostic log messages should be enabled. */
@property(nonatomic, readonly) BOOL diagnosticsEnabled;

- (nullable instancetype)init NS_UNAVAILABLE;

/** Singleton instance of FPRConfigurations. */
+ (nullable instancetype)sharedInstance;

/**
 * Updates all the configurations flags relevant to Firebase Performance.
 *
 * This call blocks until the update is done.
 */
- (void)update;

#pragma mark - Configuration fetcher methods.

/**
 * Returns the percentage of instances that would send trace events. Range [0-1].
 *
 * @return The percentage of instances that would send trace events.
 */
- (float)logTraceSamplingRate;

/**
 * Returns the percentage of instances that would send network request events. Range [0-1].
 *
 * @return The percentage of instances that would send network request events.
 */
- (float)logNetworkSamplingRate;

/**
 * Returns the foreground event count/burst size. This is the number of events that are allowed to
 * flow in burst when the app is in foreground.
 *
 * @return The foreground event count as determined from configs.
 */
- (uint32_t)foregroundEventCount;

/**
 * Returns the foreground time limit to allow the foreground event count. This is specified in
 * number of minutes.
 *
 * @return The foreground event time limit as determined from configs.
 */
- (uint32_t)foregroundEventTimeLimit;

/**
 * Returns the background event count/burst size. This is the number of events that are allowed to
 * flow in burst when the app is in background.
 *
 * @return The background event count as determined from configs.
 */
- (uint32_t)backgroundEventCount;

/**
 * Returns the background time limit to allow the background event count. This is specified in
 * number of minutes.
 *
 * @return The background event time limit as determined from configs.
 */
- (uint32_t)backgroundEventTimeLimit;

/**
 * Returns the foreground network event count/burst size. This is the number of network events that
 * are allowed to flow in burst when the app is in foreground.
 *
 * @return The foreground network event count as determined from configs.
 */
- (uint32_t)foregroundNetworkEventCount;

/**
 * Returns the foreground time limit to allow the foreground network event count. This is specified
 * in number of minutes.
 *
 * @return The foreground network event time limit as determined from configs.
 */
- (uint32_t)foregroundNetworkEventTimeLimit;

/**
 * Returns the background network event count/burst size. This is the number of network events that
 * are allowed to flow in burst when the app is in background.
 *
 * @return The background network event count as determined from configs.
 */
- (uint32_t)backgroundNetworkEventCount;

/**
 * Returns the background time limit to allow the background network event count. This is specified
 * in number of minutes.
 *
 * @return The background network event time limit as determined from configs.
 */
- (uint32_t)backgroundNetworkEventTimeLimit;

/**
 * Returns a float specifying the percentage of device instances on which session feature is
 * enabled. Range [0-100].
 *
 * @return The percentage of devices on which session feature should be enabled.
 */
- (float_t)sessionsSamplingPercentage;

/**
 * Returns the maximum length of a session in minutes. Default is 240 minutes.
 *
 * @return Maximum allowed length of the session in minutes.
 */
- (uint32_t)maxSessionLengthInMinutes;

/**
 * Returns the frequency at which the CPU usage metrics are to be collected when the app is in the
 * foreground. Frequency is specified in milliseconds. A value of '0' means do not capture.
 *
 * @return An integer value specifying the frequency of capture in milliseconds.
 */
- (uint32_t)cpuSamplingFrequencyInForegroundInMS;

/**
 * Returns the frequency at which the CPU usage metrics are to be collected when the app is in the
 * background. Frequency is specified in milliseconds. A value of '0' means do not capture.
 *
 * @return An integer value specifying the frequency of capture in milliseconds.
 */
- (uint32_t)cpuSamplingFrequencyInBackgroundInMS;

/**
 * Returns the frequency at which the memory usage metrics are to be collected when the app is in
 * the foreground. Frequency is specified in milliseconds. A value of '0' means do not capture.
 *
 * @return An integer value specifying the frequency of capture in milliseconds.
 */
- (uint32_t)memorySamplingFrequencyInForegroundInMS;

/**
 * Returns the frequency at which the memory usage metrics are to be collected when the app is in
 * the background. Frequency is specified in milliseconds. A value of '0' means do not capture.
 *
 * @return An integer value specifying the frequency of capture in milliseconds.
 */
- (uint32_t)memorySamplingFrequencyInBackgroundInMS;

/**
 * Returns a float specifying the transport percentage for FLL. Range [0-100].
 *
 * @return The percentage of devices sending events to FLL.
 */
- (float_t)fllTransportPercentage;

@end

NS_ASSUME_NONNULL_END
