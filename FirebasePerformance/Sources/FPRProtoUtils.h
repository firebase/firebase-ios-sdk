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

#import <TargetConditionals.h>
#if __has_include("CoreTelephony/CTTelephonyNetworkInfo.h") && !TARGET_OS_MACCATALYST
#define TARGET_HAS_MOBILE_CONNECTIVITY
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#endif

#import "FirebasePerformance/Sources/AppActivity/FPRTraceBackgroundActivityTracker.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"
#import "FirebasePerformance/Sources/Public/FIRTrace.h"

#import "FirebasePerformance/ProtoSupport/PerfMetric.pbobjc.h"
#import "FirebasePerformance/Sources/Protogen/nanopb/perf_metric.nanopb.h"

extern pb_bytes_array_t* _Nullable FPREncodeData(NSData* _Nonnull data);

extern pb_bytes_array_t* _Nullable FPREncodeString(NSString* _Nonnull string);

extern NSData* _Nullable FPRDecodeData(pb_bytes_array_t* _Nonnull pbData);

extern NSString* _Nullable FPRDecodeString(pb_bytes_array_t* _Nonnull pbData);

extern NSMutableDictionary<NSString*, NSString*>* _Nullable FPRDecodeCustomAttributes(
    struct _firebase_perf_v1_ApplicationInfo_CustomAttributesEntry* _Nullable customAttributes,
    NSInteger count);

/** Creates a new firebase_perf_v1_PerfMetric proto object populated with system metadata.
 *  @param appID The Google app id to put into the message
 *  @return Reference to a FPRMSGPerfMetric object.
 */
extern firebase_perf_v1_PerfMetric FPRGetPerfMetricMessage(NSString* _Nonnull appID);

/** Creates a new firebase_perf_v1_ApplicationInfo proto object populated with system metadata.
 *  @return Reference to a FPRMSGApplicationInfo object.
 */
extern firebase_perf_v1_ApplicationInfo FPRGetApplicationInfoMessage(void);

/** Converts the FIRTrace object to a firebase_perf_v1_TraceMetric proto object.
 *  @return Reference to a FPRMSGTraceMetric object.
 */
extern firebase_perf_v1_TraceMetric FPRGetTraceMetric(FIRTrace* _Nonnull trace);

/** Converts the FPRNetworkTrace object to a FPRMSGNetworkRequestMetric proto object.
 *  @return Reference to a FPRMSGNetworkRequestMetric object.
 */
extern FPRMSGNetworkRequestMetric* _Nullable FPRGetNetworkRequestMetric(
    FPRNetworkTrace* _Nonnull trace);

/** Converts the gaugeData array object to a FPRMSGGaugeMetric proto object.
 *  @return Reference to a FPRMSGGaugeMetric object.
 */
extern FPRMSGGaugeMetric* _Nullable FPRGetGaugeMetric(NSArray* _Nonnull gaugeData,
                                                      NSString* _Nonnull sessionId);

/** Converts the FPRTraceState to a FPRMSGApplicationProcessState proto value.
 *  @return FPRMSGApplicationProcessState value.
 */
extern firebase_perf_v1_ApplicationProcessState FPRApplicationProcessState(FPRTraceState state);

#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
/** Obtain a CTTelephonyNetworkInfo object to determine device network attributes.
 *  @return CTTelephonyNetworkInfo object.
 */
extern CTTelephonyNetworkInfo* _Nullable FPRNetworkInfo(void);
#endif
