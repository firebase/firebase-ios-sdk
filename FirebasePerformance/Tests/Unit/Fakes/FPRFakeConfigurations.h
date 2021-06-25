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

#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"

NS_ASSUME_NONNULL_BEGIN

// This is a fake Remote Config class to manipulate the inputs.
@interface FPRFakeConfigurations : FPRConfigurations

#pragma mark - Global configurations.

/**
 * Sets the data collection state for configurations.
 *
 * @param dataCollectionEnabled Data collection state to be set.
 */
- (void)setDataCollectionEnabled:(BOOL)dataCollectionEnabled;

/**
 * Sets the instrumentation state for configurations.
 *
 * @param instrumentationEnabled Instrumentation  state to be set.
 */
- (void)setInstrumentationEnabled:(BOOL)instrumentationEnabled;

/**
 * Sets the log source for configurations.
 *
 * @param logSource Log source to be set.
 */
- (void)setLogSource:(int)logSource;

/**
 * Sets the SDK enabled state for configurations.
 *
 * @param enabled SDK enabled state to be set.
 */
- (void)setSdkEnabled:(BOOL)enabled;

/**
 * Sets the Diagnostics enabled state for configurations.
 *
 * @param enabled Diagnostics enabled state to be set.
 */
- (void)setDiagnosticsEnabled:(BOOL)enabled;

#pragma mark - Sampling related configurations.

/**
 * Sets the trace sampling rate for configurations.
 *
 * @param rate Trace sampling rate to be set.
 */
- (void)setTraceSamplingRate:(float)rate;

/**
 * Sets the network sampling rate for configurations.
 *
 * @param rate Network sampling rate to be set.
 */
- (void)setNetworkSamplingRate:(float)rate;

#pragma mark - Rate limiting related configurations.

/**
 * Sets the foreground trace event count for configurations.
 *
 * @param eventCount Foreground event count to be set.
 */
- (void)setForegroundEventCount:(uint32_t)eventCount;

/**
 * Sets the foreground trace time limit for configurations.
 *
 * @param timeLimit Foreground time limit to be set.
 */
- (void)setForegroundTimeLimit:(uint32_t)timeLimit;

/**
 * Sets the background trace event count for configurations.
 *
 * @param eventCount Background event count to be set.
 */
- (void)setBackgroundEventCount:(uint32_t)eventCount;

/**
 * Sets the background trace time limit for configurations.
 *
 * @param timeLimit Background time limit to be set.
 */
- (void)setBackgroundTimeLimit:(uint32_t)timeLimit;

/**
 * Sets the foreground network trace event count for configurations.
 *
 * @param eventCount Foreground network event count to be set.
 */
- (void)setForegroundNetworkEventCount:(uint32_t)eventCount;

/**
 * Sets the foreground network trace time limit for configurations.
 *
 * @param timeLimit Foreground network time limit to be set.
 */
- (void)setForegroundNetworkTimeLimit:(uint32_t)timeLimit;

/**
 * Sets the background network trace event count for configurations.
 *
 * @param eventCount Background network event count to be set.
 */
- (void)setBackgroundNetworkEventCount:(uint32_t)eventCount;

/**
 * Sets the background network trace time limit for configurations.
 *
 * @param timeLimit Background network time limit to be set.
 */
- (void)setBackgroundNetworkTimeLimit:(uint32_t)timeLimit;

#pragma mark - Session related configurations.

/**
 * Sets the session sampling rate for configurations.
 *
 * @param rate Sessions sampling rate to be set.
 */
- (void)setSessionsSamplingPercentage:(float)rate;

/**
 * Sets the max length of sessions (in minutes) for configurations.
 *
 * @param minutes Maximum sessions length to be set.
 */
- (void)setMaxSessionLengthInMinutes:(uint32_t)minutes;

/**
 * Sets the CPU sampling frequency when app is in foreground for configurations.
 *
 * @param frequency CPU sampling frequency when app is in foreground.
 */
- (void)setCpuSamplingFrequencyInForegroundInMS:(uint32_t)frequency;

/**
 * Sets the CPU sampling frequency when app is in background for configurations.
 *
 * @param frequency CPU sampling frequency when app is in background.
 */
- (void)setCpuSamplingFrequencyInBackgroundInMS:(uint32_t)frequency;

/**
 * Sets the memory sampling frequency when app is in foreground for configurations.
 *
 * @param frequency memory sampling frequency when app is in foreground.
 */
- (void)setMemorySamplingFrequencyInForegroundInMS:(uint32_t)frequency;

/**
 * Sets the memory sampling frequency when app is in background for configurations.
 *
 * @param frequency memory sampling frequency when app is in background.
 */
- (void)setMemorySamplingFrequencyInBackgroundInMS:(uint32_t)frequency;

@end

NS_ASSUME_NONNULL_END
