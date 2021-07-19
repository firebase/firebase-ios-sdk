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
#import "FirebasePerformance/Sources/Public/FIRTrace.h"

#import "FirebasePerformance/Sources/Protogen/nanopb/perf_metric.nanopb.h"

typedef struct {
  pb_bytes_array_t* _Nonnull key;
  pb_bytes_array_t* _Nonnull value;
} StringToStringMap;

typedef struct {
  pb_bytes_array_t* _Nonnull key;
  bool has_value;
  int64_t value;
} StringToNumberMap;

extern pb_bytes_array_t* _Nullable FPREncodeData(NSData* _Nonnull data);

extern pb_bytes_array_t* _Nullable FPREncodeString(NSString* _Nonnull string);

extern NSData* _Nullable FPRDecodeData(pb_bytes_array_t* _Nonnull pbData);

extern NSString* _Nullable FPRDecodeString(pb_bytes_array_t* _Nonnull pbData);

extern NSDictionary<NSString*, NSString*>* _Nullable FPRDecodeStringToStringMap(
    StringToStringMap* _Nullable map, NSInteger count);

extern StringToStringMap* _Nullable FPREncodeStringToStringMap(NSDictionary* _Nullable dict);

extern NSDictionary<NSString*, NSNumber*>* _Nullable FPRDecodeStringToNumberMap(
    StringToNumberMap* _Nullable map, NSInteger count);

extern StringToNumberMap* _Nullable FPREncodeStringToNumberMap(NSDictionary* _Nullable dict);

/** Creates a new firebase_perf_v1_PerfMetric struct populated with system metadata.
 *  @param appID The Google app id to put into the message
 *  @return A firebase_perf_v1_PerfMetric struct.
 */
extern firebase_perf_v1_PerfMetric GetPerfMetricMessage(NSString* _Nonnull appID);

/** Creates a new firebase_perf_v1_ApplicationInfo struct populated with system metadata.
 *  @return A firebase_perf_v1_ApplicationInfo struct.
 */
extern firebase_perf_v1_ApplicationInfo GetApplicationInfoMessage(void);

/** Converts the FIRTrace object to a firebase_perf_v1_TraceMetric struct.
 *  @return A firebase_perf_v1_TraceMetric struct.
 */
extern firebase_perf_v1_TraceMetric GetTraceMetric(FIRTrace* _Nonnull trace);

/** Converts the FPRNetworkTrace object to a firebase_perf_v1_NetworkRequestMetric struct.
 *  @return A firebase_perf_v1_NetworkRequestMetric struct.
 */
extern firebase_perf_v1_NetworkRequestMetric GetNetworkRequestMetric(
    FPRNetworkTrace* _Nonnull trace);

/** Converts the gaugeData array object to a firebase_perf_v1_GaugeMetric struct.
 *  @return A firebase_perf_v1_GaugeMetric struct.
 */
extern firebase_perf_v1_GaugeMetric GetGaugeMetric(NSArray* _Nonnull gaugeData,
                                                   NSString* _Nonnull sessionId);

/** Converts the FPRTraceState to a firebase_perf_v1_ApplicationProcessState struct.
 *  @return A firebase_perf_v1_ApplicationProcessState struct.
 */
extern firebase_perf_v1_ApplicationProcessState ApplicationProcessState(FPRTraceState state);

#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
/** Obtain a CTTelephonyNetworkInfo object to determine device network attributes.
 *  @return CTTelephonyNetworkInfo object.
 */
extern CTTelephonyNetworkInfo* _Nullable NetworkInfo(void);
#endif
