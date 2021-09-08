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

#import <TargetConditionals.h>
#if __has_include("CoreTelephony/CTTelephonyNetworkInfo.h") && !TARGET_OS_MACCATALYST
#define TARGET_HAS_MOBILE_CONNECTIVITY
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#endif

#import "FirebasePerformance/Sources/AppActivity/FPRTraceBackgroundActivityTracker.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRTrace.h"

#import "FirebasePerformance/Sources/Protogen/nanopb/perf_metric.nanopb.h"

/**nanopb struct of encoded NSDictionary<NSString *, NSString *>.*/
typedef struct {
  pb_bytes_array_t* _Nonnull key;
  pb_bytes_array_t* _Nonnull value;
} StringToStringMap;

/**nanopb struct of encoded NSDictionary<NSString *, NSNumber *>.*/
typedef struct {
  pb_bytes_array_t* _Nonnull key;
  bool has_value;
  int64_t value;
} StringToNumberMap;

/** Callocs a pb_bytes_array and copies the given NSData bytes into the bytes array.
 *
 * @note Memory needs to be free manually, through pb_free or pb_release.
 * @param data The data to copy into the new bytes array.
 * @return pb_byte array
 */
extern pb_bytes_array_t* _Nullable FPREncodeData(NSData* _Nonnull data);

/** Callocs a pb_bytes_array and copies the given NSString's bytes into the bytes array.
 *
 * @note Memory needs to be free manually, through pb_free or pb_release.
 * @param string The string to encode as pb_bytes.
 * @return pb_byte array
 */
extern pb_bytes_array_t* _Nullable FPREncodeString(NSString* _Nonnull string);

/** Callocs a nanopb StringToStringMap and copies the given NSDictionary bytes into the
 * StringToStringMap.
 *
 * @param dict The dict to copy into the new StringToStringMap.
 * @return A reference to StringToStringMap
 */
extern StringToStringMap* _Nullable FPREncodeStringToStringMap(NSDictionary* _Nullable dict);

/** Callocs a nanopb StringToNumberMap and copies the given NSDictionary bytes into the
 * StringToStringMap.
 *
 * @param dict The dict to copy into the new StringToNumberMap.
 * @return A reference to StringToNumberMap
 */
extern StringToNumberMap* _Nullable FPREncodeStringToNumberMap(NSDictionary* _Nullable dict);

/** Creates a new firebase_perf_v1_PerfMetric struct populated with system metadata.
 *  @param appID The Google app id to put into the message
 *  @return A firebase_perf_v1_PerfMetric struct.
 */
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
extern firebase_perf_v1_PerfMetric FPRGetPerfMetricMessage(NSString* _Nonnull appID);

/** Creates a new firebase_perf_v1_ApplicationInfo struct populated with system metadata.
 *  @return A firebase_perf_v1_ApplicationInfo struct.
 */
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
extern firebase_perf_v1_ApplicationInfo FPRGetApplicationInfoMessage(void);

/** Converts the FIRTrace object to a firebase_perf_v1_TraceMetric struct.
 *  @return A firebase_perf_v1_TraceMetric struct.
 */
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
extern firebase_perf_v1_TraceMetric FPRGetTraceMetric(FIRTrace* _Nonnull trace);

/** Converts the FPRNetworkTrace object to a firebase_perf_v1_NetworkRequestMetric struct.
 *  @return A firebase_perf_v1_NetworkRequestMetric struct.
 */
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
extern firebase_perf_v1_NetworkRequestMetric FPRGetNetworkRequestMetric(
    FPRNetworkTrace* _Nonnull trace);

/** Converts the gaugeData array object to a firebase_perf_v1_GaugeMetric struct.
 *  @return A firebase_perf_v1_GaugeMetric struct.
 */
extern firebase_perf_v1_GaugeMetric FPRGetGaugeMetric(NSArray* _Nonnull gaugeData,
                                                      NSString* _Nonnull sessionId);

/** Converts the FPRTraceState to a firebase_perf_v1_ApplicationProcessState struct.
 *  @return A firebase_perf_v1_ApplicationProcessState struct.
 */
extern firebase_perf_v1_ApplicationProcessState FPRApplicationProcessState(FPRTraceState state);

/** Populate a firebase_perf_v1_PerfMetric object with the given firebase_perf_v1_ApplicationInfo.
 *
 *  @param perfMetric The reference to a firebase_perf_v1_PerfMetric object to be populated.
 *  @param appInfo The firebase_perf_v1_ApplicationInfo object that will be added to
 * firebase_perf_v1_PerfMetric.
 */
extern void FPRSetApplicationInfo(firebase_perf_v1_PerfMetric* _Nonnull perfMetric,
                                  firebase_perf_v1_ApplicationInfo appInfo);

/** Populate a firebase_perf_v1_PerfMetric object with the given firebase_perf_v1_TraceMetric.
 *
 *  @param perfMetric The reference to firebase_perf_v1_PerfMetric to be populated.
 *  @param traceMetric The firebase_perf_v1_TraceMetric object that will be added to
 * firebase_perf_v1_PerfMetric.
 */
extern void FPRSetTraceMetric(firebase_perf_v1_PerfMetric* _Nonnull perfMetric,
                              firebase_perf_v1_TraceMetric traceMetric);

/** Populate a firebase_perf_v1_PerfMetric object with the given
 * firebase_perf_v1_NetworkRequestMetric.
 *
 *  @param perfMetric The reference to a firebase_perf_v1_PerfMetric object to be populated.
 *  @param networkMetric The firebase_perf_v1_NetworkRequestMetric object that will be added to
 * firebase_perf_v1_PerfMetric.
 */
extern void FPRSetNetworkRequestMetric(firebase_perf_v1_PerfMetric* _Nonnull perfMetric,
                                       firebase_perf_v1_NetworkRequestMetric networkMetric);

/** Populate a firebase_perf_v1_PerfMetric object with the given firebase_perf_v1_GaugeMetric.
 *
 *  @param perfMetric The reference to a firebase_perf_v1_PerfMetric object to be populated.
 *  @param gaugeMetric The firebase_perf_v1_GaugeMetric object that will be added to
 * firebase_perf_v1_PerfMetric.
 */
extern void FPRSetGaugeMetric(firebase_perf_v1_PerfMetric* _Nonnull perfMetric,
                              firebase_perf_v1_GaugeMetric gaugeMetric);

/** Populate a firebase_perf_v1_PerfMetric object with the given
 * firebase_perf_v1_ApplicationProcessState.
 *
 *  @param perfMetric The reference to a firebase_perf_v1_PerfMetric object to be populated.
 *  @param state The firebase_perf_v1_ApplicationProcessState object that will be added to
 * firebase_perf_v1_PerfMetric.
 */
extern void FPRSetApplicationProcessState(firebase_perf_v1_PerfMetric* _Nonnull perfMetric,
                                          firebase_perf_v1_ApplicationProcessState state);

#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
/** Obtain a CTTelephonyNetworkInfo object to determine device network attributes.
 *  @return CTTelephonyNetworkInfo object.
 */
extern CTTelephonyNetworkInfo* _Nullable FPRNetworkInfo(void);
#endif
