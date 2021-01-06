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

/**
 * Configuration flags retrieved from Firebase Remote Configuration.
 */
@interface FPRRemoteConfigFlags : NSObject

/**
 * The name of the name space for which the remote config flags are fetched.
 */
@property(nonatomic, readonly, nonnull) NSString *remoteConfigNamespace;

#pragma mark - Instance methods

- (nullable instancetype)init NS_UNAVAILABLE;

/** Singleton instance of Firebase Remote Configuration flags. */
+ (nullable instancetype)sharedInstance;

/**
 * Initiate a fetch of the flags from Firebase Remote Configuration and updates the configurations
 * at the end of the fetch.
 *
 * @note This method is throttled to initiate a fetch once in 12 hours. So, calling this method does
 * not guarantee a fetch from Firebase Remote Config.
 */
- (void)update;

/**
 * Returns if there was a successful fetch in the past and if any remote config flag exists.
 *
 * @return YES if any remote config flag exists; NO otherwise.
 */
- (BOOL)containsRemoteConfigFlags;

#pragma mark - General configs.

/**
 * Returns if performance SDK is enabled.
 * Name in remote config: "fpr_enabled".
 *
 * @param sdkEnabled Default value to be returned if values does not exist in remote config.
 * @return Specifies if SDK should be enabled or not.
 */
- (BOOL)performanceSDKEnabledWithDefaultValue:(BOOL)sdkEnabled;

/**
 * Returns set of versions on which SDK is disabled.
 * Name in remote config: "fpr_disabled_ios_versions".
 *
 * @param sdkVersions Default value to be returned if values does not exist in remote config.
 * @return SDK versions list where the SDK has to be disabled.
 */
- (nullable NSSet<NSString *> *)sdkDisabledVersionsWithDefaultValue:
    (nullable NSSet<NSString *> *)sdkVersions;

/**
 * Returns the log source against which the events will be recorded.
 * Name in remote config: "fpr_log_source"
 *
 * @param logSource Default value to be returned if values does not exist in remote config.
 * @return Log source towards which the events would be logged.
 */
- (int)logSourceWithDefaultValue:(int)logSource;

#pragma mark - Rate limiting related configs.

/**
 * Returns the time limit for which the event are measured against. Measured in seconds.
 * Name in remote config: "fpr_rl_time_limit_sec"
 *
 * @param durationInSeconds Default value to be returned if values does not exist in remote config.
 * @return Time limit used for rate limiting in seconds.
 */
- (int)rateLimitTimeDurationWithDefaultValue:(int)durationInSeconds;

/**
 * Returns the number of trace events that are allowed when the app is in foreground.
 * Name in remote config: "fpr_rl_trace_event_count_fg"
 *
 * @param eventCount Default value to be returned if values does not exist in remote config.
 * @return Trace count limit when the app is in foreground.
 */
- (int)rateLimitTraceCountInForegroundWithDefaultValue:(int)eventCount;

/**
 * Returns the number of trace events that are allowed when the app is in background.
 * Name in remote config: "fpr_rl_trace_event_count_bg"
 *
 * @param eventCount Default value to be returned if values does not exist in remote config.
 * @return Trace count limit when the app is in background.
 */
- (int)rateLimitTraceCountInBackgroundWithDefaultValue:(int)eventCount;

/**
 * Returns the number of network trace events that are allowed when the app is in foreground.
 * Name in remote config: "fpr_rl_network_request_event_count_fg"
 *
 * @param eventCount Default value to be returned if values does not exist in remote config.
 * @return Network request count limit when the app is in foreground.
 */
- (int)rateLimitNetworkRequestCountInForegroundWithDefaultValue:(int)eventCount;

/**
 * Returns the number of network trace events that are allowed when the app is in background.
 * Name in remote config: "fpr_rl_network_request_event_count_bg"
 *
 * @param eventCount Default value to be returned if values does not exist in remote config.
 * @return Network request count limit when the app is in background.
 */
- (int)rateLimitNetworkRequestCountInBackgroundWithDefaultValue:(int)eventCount;

#pragma mark - Sampling related configs.

/**
 * Returns the sampling rate for traces. A value of 1 means all the events must be sent to the
 * backend. A value of 0 means, no data must be sent. Range [0-1]. A value of -1 means the value is
 * not found.
 * Name in remote config: "fpr_vc_trace_sampling_rate"
 *
 * @param samplingRate Default value to be returned if values does not exist in remote config.
 * @return Sampling rate used for the number of traces.
 */
- (float)traceSamplingRateWithDefaultValue:(float)samplingRate;

/**
 * Returns the sampling rate for network requests. A value of 1 means all the events must be sent to
 * the backend. A value of 0 means, no data must be sent. Range [0-1]. A value of -1 means the value
 * is not found.
 * Name in remote config: "fpr_vc_network_request_sampling_rate"
 *
 * @param samplingRate Default value to be returned if values does not exist in remote config.
 * @return Sampling rate used for the number of network request traces.
 */
- (float)networkRequestSamplingRateWithDefaultValue:(float)samplingRate;

#pragma mark - Session related configs.

/**
 * Returns the sampling rate for sessions. A value of 1 means all the events must be sent to the
 * backend. A value of 0 means, no data must be sent. Range [0-1]. A value of -1 means the value is
 * not found.
 * Name in remote config: "fpr_vc_session_sampling_rate"
 *
 * @param samplingRate Default value to be returned if values does not exist in remote config.
 * @return Session sampling rate used for the number of sessions generated.
 */
- (float)sessionSamplingRateWithDefaultValue:(float)samplingRate;

/**
 * Returns the frequency at which CPU usage is measured when the app is in foreground. Measured in
 * milliseconds. Name in remote config: "fpr_session_gauge_cpu_capture_frequency_fg_ms"
 *
 * @param defaultFrequency Default value to be returned if values does not exist in remote config.
 * @return Frequency at which CPU information is captured when app is in foreground.
 */
- (int)sessionGaugeCPUCaptureFrequencyInForegroundWithDefaultValue:(int)defaultFrequency;

/**
 * Returns the frequency at which CPU usage is measured when the app is in background. Measured in
 * milliseconds. Name in remote config: "fpr_session_gauge_cpu_capture_frequency_bg_ms"
 *
 * @param defaultFrequency Default value to be returned if values does not exist in remote config.
 * @return Frequency at which CPU information is captured when app is in background.
 */
- (int)sessionGaugeCPUCaptureFrequencyInBackgroundWithDefaultValue:(int)defaultFrequency;

/**
 * Returns the frequency at which memory usage is measured when the app is in foreground. Measured
 * in milliseconds. Name in remote config: "fpr_session_gauge_memory_capture_frequency_fg_ms"
 *
 * @param defaultFrequency Default value to be returned if values does not exist in remote config.
 * @return Frequency at which memory information is captured when app is in foreground.
 */
- (int)sessionGaugeMemoryCaptureFrequencyInForegroundWithDefaultValue:(int)defaultFrequency;

/**
 * Returns the frequency at which memory usage is measured when the app is in background. Measured
 * in milliseconds. Name in remote config: "fpr_session_gauge_memory_capture_frequency_bg_ms"
 *
 * @param defaultFrequency Default value to be returned if values does not exist in remote config.
 * @return Frequency at which memory information is captured when app is in background.
 */
- (int)sessionGaugeMemoryCaptureFrequencyInBackgroundWithDefaultValue:(int)defaultFrequency;

/**
 * Returns the maximum allowed duration for the length of a session. Measured in minutes.
 * Name in remote config: "fpr_session_max_duration_min"
 *
 * @param maxDurationInMinutes Default value to be returned if values does not exist in remote
 * config.
 * @return Duration for which a sessions can be active.
 */
- (int)sessionMaxDurationWithDefaultValue:(int)maxDurationInMinutes;

#pragma mark - Google Data Transport related configs.

/**
 * Returns the fll event transport percentage. A value of 100 means all the events are sent to
 * Fll. A value of 0 means, event are not sent to FLL. Range [0-100]. A value of -1 means
 * the value is not found. Name in remote config: "fpr_log_transport_ios_percent"
 *
 * @param percentage Default value of the transport rate to be returned if value does not exist
 * in remote config.
 * @return FLL transport percentage.
 */
- (float)fllTransportPercentageWithDefaultValue:(float)percentage;

@end
