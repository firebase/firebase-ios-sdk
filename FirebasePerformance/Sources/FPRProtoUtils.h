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

#import <CoreTelephony/CTTelephonyNetworkInfo.h>

#import "FirebasePerformance/Sources/AppActivity/FPRTraceBackgroundActivityTracker.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"
#import "FirebasePerformance/Sources/Public/FIRTrace.h"

#import "FirebasePerformance/ProtoSupport/PerfMetric.pbobjc.h"

/** Creates a new FPRMSGPerfMetric proto object populated with system metadata.
 *  @param appID The Google app id to put into the message
 *  @return Reference to a FPRMSGPerfMetric object.
 */
extern FPRMSGPerfMetric* _Nullable FPRGetPerfMetricMessage(NSString* _Nonnull appID);

/** Creates a new FPRMSGApplicationInfo proto object populated with system metadata.
 *  @return Reference to a FPRMSGApplicationInfo object.
 */
extern FPRMSGApplicationInfo* _Nullable FPRGetApplicationInfoMessage(void);

/** Converts the FIRTrace object to a FPRMSGTraceMetric proto object.
 *  @return Reference to a FPRMSGTraceMetric object.
 */
extern FPRMSGTraceMetric* _Nullable FPRGetTraceMetric(FIRTrace* _Nonnull trace);

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
extern FPRMSGApplicationProcessState FPRApplicationProcessState(FPRTraceState state);

/** Obtain a CTTelephonyNetworkInfo object to determine device network attributes.
 *  @return CTTelephonyNetworkInfo object.
 */
extern CTTelephonyNetworkInfo* _Nullable FPRNetworkInfo(void);
