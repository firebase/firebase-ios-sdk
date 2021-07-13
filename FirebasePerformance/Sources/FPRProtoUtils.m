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

#import "FirebasePerformance/Sources/FPRProtoUtils.h"

#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#endif
#import <SystemConfiguration/SystemConfiguration.h>

#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/FIRPerformance+Internal.h"
#import "FirebasePerformance/Sources/FPRDataUtils.h"
#import "FirebasePerformance/Sources/Public/FIRPerformance.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Private.h"

#import "FirebasePerformance/Sources/Gauges/CPU/FPRCPUGaugeData.h"
#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeData.h"

#define BYTES_TO_KB(x) (x / 1024)

//static GPBStringInt64Dictionary *FPRGetProtoCounterForDictionary(
//    NSDictionary<NSString *, NSNumber *> *dictionary);
static firebase_perf_v1_NetworkRequestMetric_HttpMethod FPRHTTPMethodForString(NSString *methodString);
static firebase_perf_v1_NetworkConnectionInfo_NetworkType FPRNetworkConnectionInfoNetworkType(void);
#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
static firebase_perf_v1_NetworkConnectionInfo_MobileSubtype FPRCellularNetworkType(void);
#endif
NSArray<FPRSessionDetails *> *FPRMakeFirstSessionVerbose(NSArray<FPRSessionDetails *> *sessions);

#pragma mark - Private methods

pb_bytes_array_t *FPREncodeData(NSData *data) {
  pb_bytes_array_t *pbBytesArray = calloc(1, PB_BYTES_ARRAY_T_ALLOCSIZE(data.length));
  if (pbBytesArray != NULL) {
    [data getBytes:pbBytesArray->bytes length:data.length];
    pbBytesArray->size = (pb_size_t)data.length;
  }
  return pbBytesArray;
}

pb_bytes_array_t *FPREncodeString(NSString *string) {
  NSData *stringBytes = [string dataUsingEncoding:NSUTF8StringEncoding];
  return FPREncodeData(stringBytes);
}

NSData *FPRDecodeData(pb_bytes_array_t *pbData) {
  NSData *data = [NSData dataWithBytesNoCopy:pbData length:sizeof(pbData) freeWhenDone:YES];
  return data;
}

NSString *FPRDecodeString(pb_bytes_array_t *pbData) {
  NSData *data = FPRDecodeData(pbData);
  return [NSString stringWithCString:[data bytes] encoding:NSUTF8StringEncoding];
}

#pragma mark - Public methods

firebase_perf_v1_PerfMetric FPRGetPerfMetricMessage(NSString *appID) {
  firebase_perf_v1_PerfMetric perfMetricMessage = firebase_perf_v1_PerfMetric_init_default;
  perfMetricMessage.application_info = FPRGetApplicationInfoMessage();
  perfMetricMessage.application_info.google_app_id = FPREncodeString(appID);

  return perfMetricMessage;
}

firebase_perf_v1_ApplicationInfo FPRGetApplicationInfoMessage() {
  firebase_perf_v1_ApplicationInfo appInfoMessage = firebase_perf_v1_ApplicationInfo_init_default;
  firebase_perf_v1_IosApplicationInfo iosAppInfo = firebase_perf_v1_IosApplicationInfo_init_default;
  NSBundle *mainBundle = [NSBundle mainBundle];
  iosAppInfo.bundle_short_version = FPREncodeString([mainBundle infoDictionary][@"CFBundleShortVersionString"]);
  iosAppInfo.sdk_version = FPREncodeString([NSString stringWithUTF8String:kFPRSDKVersion]);
  iosAppInfo.network_connection_info.network_type = FPRNetworkConnectionInfoNetworkType();
#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
  CTTelephonyNetworkInfo *networkInfo = FPRNetworkInfo();
  CTCarrier *provider = networkInfo.subscriberCellularProvider;
  NSString *mccMnc = FPRValidatedMccMnc(provider.mobileCountryCode, provider.mobileNetworkCode);
  if (mccMnc) {
    iosAppInfo.mcc_mnc = FPREncodeString(mccMnc);
  }
  if (iosAppInfo.network_connection_info.network_type == firebase_perf_v1_NetworkConnectionInfo_NetworkType_MOBILE) {
    iosAppInfo.network_connection_info.mobile_subtype = FPRCellularNetworkType();
  }
#endif
  appInfoMessage.ios_app_info = iosAppInfo;

  //TODO(visum) Enable custom attributes
  NSDictionary<NSString *, NSString *> *attributes = [[FIRPerformance sharedInstance].attributes mutableCopy];
//  firebase_perf_v1_ApplicationInfo_CustomAttributesEntry customAttributes = firebase_perf_v1_ApplicationInfo_CustomAttributesEntry_init_default;
  firebase_perf_v1_ApplicationInfo_CustomAttributesEntry *customAttributes = calloc(attributes.count, sizeof(firebase_perf_v1_ApplicationInfo_CustomAttributesEntry));
  [attributes enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
    firebase_perf_v1_ApplicationInfo_CustomAttributesEntry attributeEntry = firebase_perf_v1_ApplicationInfo_CustomAttributesEntry_init_default;
    attributeEntry.key = FPREncodeString(key);
    attributeEntry.value = FPREncodeString(value);
  }];
  
//  appInfoMessage.custom_attributes = customAttributes;

  return appInfoMessage;
}

firebase_perf_v1_TraceMetric FPRGetTraceMetric(FIRTrace *trace) {
  firebase_perf_v1_TraceMetric traceMetric = firebase_perf_v1_TraceMetric_init_default;
  traceMetric.name = FPREncodeString(trace.name);

  // Set if the trace is an internally created trace.
  traceMetric.is_auto = trace.isInternal;

  // Convert the trace duration from seconds to microseconds.
  traceMetric.duration_us = trace.totalTraceTimeInterval * USEC_PER_SEC;

  // Convert the start time from seconds to microseconds.
  traceMetric.client_start_time_us = trace.startTimeSinceEpoch * USEC_PER_SEC;

  //TODO(visum) Enable counters
//  traceMetric.counters = FPRGetProtoCounterForDictionary(trace.counters);

  //TODO(visum) Enable subtraces
//  NSMutableArray<FPRMSGTraceMetric *> *subtraces = [[NSMutableArray alloc] init];
//  [trace.stages
//      enumerateObjectsUsingBlock:^(FIRTrace *_Nonnull stage, NSUInteger idx, BOOL *_Nonnull stop) {
//        [subtraces addObject:FPRGetTraceMetric(stage)];
//      }];
//  traceMetric.subtracesArray = subtraces;

  //TODO(visum) Enable custom attributes
//  traceMetric.customAttributes = [trace.attributes mutableCopy];

  // Fillin session details
  //TODO(visum) Enable session details
//  traceMetric.perfSessionsArray = [[NSMutableArray<FPRMSGPerfSession *> alloc] init];
//  NSArray<FPRSessionDetails *> *orderedSessions = FPRMakeFirstSessionVerbose(trace.sessions);
//  [orderedSessions enumerateObjectsUsingBlock:^(FPRSessionDetails *_Nonnull session,
//                                                NSUInteger index, BOOL *_Nonnull stop) {
//    FPRMSGPerfSession *perfSession = [FPRMSGPerfSession message];
//    perfSession.sessionId = session.sessionId;
//    perfSession.sessionVerbosityArray = [GPBEnumArray array];
//    if ((session.options & FPRSessionOptionsEvents) ||
//        (session.options & FPRSessionOptionsGauges)) {
//      [perfSession.sessionVerbosityArray addValue:FPRMSGSessionVerbosity_GaugesAndSystemEvents];
//    }
//    [traceMetric.perfSessionsArray addObject:perfSession];
//  }];

  return traceMetric;
}

firebase_perf_v1_NetworkRequestMetric FPRGetNetworkRequestMetric(FPRNetworkTrace *trace) {
  // If there is no valid status code, do not send the event to backend.
  if (!trace.hasValidResponseCode) {
    firebase_perf_v1_NetworkRequestMetric metric = firebase_perf_v1_NetworkRequestMetric_init_zero;
    return metric;
  }

  firebase_perf_v1_NetworkRequestMetric networkMetric = firebase_perf_v1_NetworkRequestMetric_init_default;
  networkMetric.url = FPREncodeString(trace.trimmedURLString);
  networkMetric.http_method = FPRHTTPMethodForString(trace.URLRequest.HTTPMethod);

  // Convert the start time from seconds to microseconds.
  networkMetric.client_start_time_us = trace.startTimeSinceEpoch * USEC_PER_SEC;

  networkMetric.request_payload_bytes = trace.requestSize;
  networkMetric.response_payload_bytes = trace.responseSize;

  networkMetric.http_response_code = trace.responseCode;
  networkMetric.response_content_type = FPREncodeString(trace.responseContentType);

  if (trace.responseError) {
    networkMetric.network_client_error_reason =
      firebase_perf_v1_NetworkRequestMetric_NetworkClientErrorReason_GENERIC_CLIENT_ERROR;
  }

  NSTimeInterval requestTimeUs =
      USEC_PER_SEC *
      [trace timeIntervalBetweenCheckpointState:FPRNetworkTraceCheckpointStateInitiated
                                       andState:FPRNetworkTraceCheckpointStateRequestCompleted];
  if (requestTimeUs > 0) {
    networkMetric.time_to_request_completed_us = requestTimeUs;
  }

  NSTimeInterval responseIntiationTimeUs =
      USEC_PER_SEC *
      [trace timeIntervalBetweenCheckpointState:FPRNetworkTraceCheckpointStateInitiated
                                       andState:FPRNetworkTraceCheckpointStateResponseReceived];
  if (responseIntiationTimeUs > 0) {
    networkMetric.time_to_response_initiated_us = responseIntiationTimeUs;
  }

  NSTimeInterval responseCompletedUs =
      USEC_PER_SEC *
      [trace timeIntervalBetweenCheckpointState:FPRNetworkTraceCheckpointStateInitiated
                                       andState:FPRNetworkTraceCheckpointStateResponseCompleted];
  if (responseCompletedUs > 0) {
    networkMetric.time_to_response_completed_us = responseCompletedUs;
  }

  //TODO(visum) Enable custom attributes
//  networkMetric.customAttributes = [trace.attributes mutableCopy];

  // Fillin session details
  //TODO(visum) Enable session details
//  NSArray<FPRSessionDetails *> *orderedSessions = FPRMakeFirstSessionVerbose(trace.sessions);
//  networkMetric.perfSessionsArray = [[NSMutableArray<FPRMSGPerfSession *> alloc] init];
//  [orderedSessions enumerateObjectsUsingBlock:^(FPRSessionDetails *_Nonnull session,
//                                                NSUInteger index, BOOL *_Nonnull stop) {
//    FPRMSGPerfSession *perfSession = [FPRMSGPerfSession message];
//    perfSession.sessionId = session.sessionId;
//    perfSession.sessionVerbosityArray = [GPBEnumArray array];
//    if ((session.options & FPRSessionOptionsEvents) ||
//        (session.options & FPRSessionOptionsGauges)) {
//      [perfSession.sessionVerbosityArray addValue:FPRMSGSessionVerbosity_GaugesAndSystemEvents];
//    }
//    [networkMetric.perfSessionsArray addObject:perfSession];
//  }];

  return networkMetric;
}

firebase_perf_v1_GaugeMetric FPRGetGaugeMetric(NSArray *gaugeData, NSString *sessionId) {
  if (gaugeData == nil || gaugeData.count == 0) {
    firebase_perf_v1_GaugeMetric metric = firebase_perf_v1_GaugeMetric_init_zero;
    return metric;
  }

  if (sessionId == nil || sessionId.length == 0) {
    firebase_perf_v1_GaugeMetric metric = firebase_perf_v1_GaugeMetric_init_zero;
    return metric;
  }

  firebase_perf_v1_GaugeMetric gaugeMetric = firebase_perf_v1_GaugeMetric_init_default;
  gaugeMetric.session_id = FPREncodeString(sessionId);
  
  //TODO(visum) Enable gauge details
//  NSMutableArray<FPRMSGCpuMetricReading *> *cpuReadings =
//      [[NSMutableArray<FPRMSGCpuMetricReading *> alloc] init];
//  NSMutableArray<FPRMSGIosMemoryReading *> *memoryReadings =
//      [[NSMutableArray<FPRMSGIosMemoryReading *> alloc] init];
//  [gaugeData enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//    if ([obj isKindOfClass:[FPRCPUGaugeData class]]) {
//      FPRCPUGaugeData *gaugeData = (FPRCPUGaugeData *)obj;
//      FPRMSGCpuMetricReading *cpuReading = [FPRMSGCpuMetricReading message];
//      cpuReading.clientTimeUs = gaugeData.collectionTime.timeIntervalSince1970 * USEC_PER_SEC;
//      cpuReading.systemTimeUs = gaugeData.systemTime;
//      cpuReading.userTimeUs = gaugeData.userTime;
//      [cpuReadings addObject:cpuReading];
//    }
//
//    if ([obj isKindOfClass:[FPRMemoryGaugeData class]]) {
//      FPRMemoryGaugeData *gaugeData = (FPRMemoryGaugeData *)obj;
//      FPRMSGIosMemoryReading *memoryReading = [FPRMSGIosMemoryReading message];
//      memoryReading.clientTimeUs = gaugeData.collectionTime.timeIntervalSince1970 * USEC_PER_SEC;
//      memoryReading.usedAppHeapMemoryKb = (int32_t)BYTES_TO_KB(gaugeData.heapUsed);
//      memoryReading.freeAppHeapMemoryKb = (int32_t)BYTES_TO_KB(gaugeData.heapAvailable);
//      [memoryReadings addObject:memoryReading];
//    }
//  }];
//  gaugeMetric.cpuMetricReadingsArray = cpuReadings;
//  gaugeMetric.iosMemoryReadingsArray = memoryReadings;
  return gaugeMetric;
}

firebase_perf_v1_ApplicationProcessState FPRApplicationProcessState(FPRTraceState state) {
  firebase_perf_v1_ApplicationProcessState processState =
    firebase_perf_v1_ApplicationProcessState_APPLICATION_PROCESS_STATE_UNKNOWN;
  switch (state) {
    case FPRTraceStateForegroundOnly:
      processState = firebase_perf_v1_ApplicationProcessState_FOREGROUND;
      break;

    case FPRTraceStateBackgroundOnly:
      processState = firebase_perf_v1_ApplicationProcessState_BACKGROUND;
      break;

    case FPRTraceStateBackgroundAndForeground:
      processState = firebase_perf_v1_ApplicationProcessState_FOREGROUND_BACKGROUND;
      break;

    default:
      break;
  }

  return processState;
}

#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
CTTelephonyNetworkInfo *FPRNetworkInfo() {
  static CTTelephonyNetworkInfo *networkInfo;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    networkInfo = [[CTTelephonyNetworkInfo alloc] init];
  });
  return networkInfo;
}
#endif

#pragma mark - Proto creation utilities

/** Converts a dictionary of <NSString *, NSNumber *> to a GPBStringInt64Dictionary proto object.
 *  @return Reference to a GPBStringInt64Dictionary object.
 */
//static GPBStringInt64Dictionary *FPRGetProtoCounterForDictionary(
//    NSDictionary<NSString *, NSNumber *> *dictionary) {
//  GPBStringInt64Dictionary *counterDictionary = [[GPBStringInt64Dictionary alloc] init];
//  [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSNumber *_Nonnull value,
//                                                  BOOL *_Nonnull stop) {
//    [counterDictionary setInt64:[value longLongValue] forKey:key];
//  }];
//
//  return counterDictionary;
//}

/** Converts the network method string to a value defined in the enum
 *  firebase_perf_v1_NetworkRequestMetric_HttpMethod.
 *  @return Enum value of the method string. If there is no mapping value defined for the method
 *      string firebase_perf_v1_NetworkRequestMetric_HttpMethod_HTTP_METHOD_UNKNOWN is returned.
 */
static firebase_perf_v1_NetworkRequestMetric_HttpMethod FPRHTTPMethodForString(NSString *methodString) {
  static NSDictionary<NSString *, NSNumber *> *HTTPToFPRNetworkTraceMethod;
  static dispatch_once_t onceToken = 0;
  dispatch_once(&onceToken, ^{
    HTTPToFPRNetworkTraceMethod = @{
      @"GET" : @(firebase_perf_v1_NetworkRequestMetric_HttpMethod_GET),
      @"POST" : @(firebase_perf_v1_NetworkRequestMetric_HttpMethod_POST),
      @"PUT" : @(firebase_perf_v1_NetworkRequestMetric_HttpMethod_PUT),
      @"DELETE" : @(firebase_perf_v1_NetworkRequestMetric_HttpMethod_DELETE),
      @"HEAD" : @(firebase_perf_v1_NetworkRequestMetric_HttpMethod_HEAD),
      @"PATCH" : @(firebase_perf_v1_NetworkRequestMetric_HttpMethod_PATCH),
      @"OPTIONS" : @(firebase_perf_v1_NetworkRequestMetric_HttpMethod_OPTIONS),
      @"TRACE" : @(firebase_perf_v1_NetworkRequestMetric_HttpMethod_TRACE),
      @"CONNECT" : @(firebase_perf_v1_NetworkRequestMetric_HttpMethod_CONNECT),
    };
  });

  NSNumber *HTTPMethod = HTTPToFPRNetworkTraceMethod[methodString];
  if (HTTPMethod == nil) {
    return firebase_perf_v1_NetworkRequestMetric_HttpMethod_HTTP_METHOD_UNKNOWN;
  }
  return HTTPMethod.intValue;
}

/** Get the current network connection type in firebase_perf_v1_NetworkConnectionInfo_NetworkType format.
 *  @return Current network connection type.
 */
static firebase_perf_v1_NetworkConnectionInfo_NetworkType FPRNetworkConnectionInfoNetworkType() {
  firebase_perf_v1_NetworkConnectionInfo_NetworkType networkType =
    firebase_perf_v1_NetworkConnectionInfo_NetworkType_NONE;

  static SCNetworkReachabilityRef reachabilityRef = 0;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    reachabilityRef = SCNetworkReachabilityCreateWithName(kCFAllocatorSystemDefault, "google.com");
  });

  SCNetworkReachabilityFlags reachabilityFlags = 0;
  SCNetworkReachabilityGetFlags(reachabilityRef, &reachabilityFlags);

  // Parse the network flags to set the network type.
  if (reachabilityFlags & kSCNetworkReachabilityFlagsReachable) {
    if (reachabilityFlags & kSCNetworkReachabilityFlagsIsWWAN) {
      networkType = firebase_perf_v1_NetworkConnectionInfo_NetworkType_MOBILE;
    } else {
      networkType = firebase_perf_v1_NetworkConnectionInfo_NetworkType_WIFI;
    }
  }

  return networkType;
}

#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
/** Get the current cellular network connection type in NetworkConnectionInfo_MobileSubtype format.
 *  @return Current cellular network connection type.
 */
static firebase_perf_v1_NetworkConnectionInfo_MobileSubtype FPRCellularNetworkType() {
  static NSDictionary<NSString *, NSNumber *> *cellularNetworkToMobileSubtype;
  static dispatch_once_t onceToken = 0;
  dispatch_once(&onceToken, ^{
    cellularNetworkToMobileSubtype = @{
      CTRadioAccessTechnologyGPRS : @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_GPRS),
      CTRadioAccessTechnologyEdge : @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_EDGE),
      CTRadioAccessTechnologyWCDMA : @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_CDMA),
      CTRadioAccessTechnologyHSDPA : @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_HSDPA),
      CTRadioAccessTechnologyHSUPA : @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_HSUPA),
      CTRadioAccessTechnologyCDMA1x : @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_CDMA),
      CTRadioAccessTechnologyCDMAEVDORev0 : @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_EVDO_0),
      CTRadioAccessTechnologyCDMAEVDORevA : @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_EVDO_A),
      CTRadioAccessTechnologyCDMAEVDORevB : @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_EVDO_B),
      CTRadioAccessTechnologyeHRPD : @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_EHRPD),
      CTRadioAccessTechnologyLTE : @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_LTE)
    };
  });

  NSString *networkString = FPRNetworkInfo().currentRadioAccessTechnology;
  NSNumber *cellularNetworkType = cellularNetworkToMobileSubtype[networkString];
  return cellularNetworkType.intValue;
}
#endif

/** Reorders the list of sessions to make sure the first session is verbose if at least one session
 *  in the list is verbose.
 *  @return Ordered list of sessions.
 */
NSArray<FPRSessionDetails *> *FPRMakeFirstSessionVerbose(NSArray<FPRSessionDetails *> *sessions) {
  NSMutableArray<FPRSessionDetails *> *orderedSessions =
      [[NSMutableArray<FPRSessionDetails *> alloc] initWithArray:sessions];

  __block NSInteger firstVerboseSessionIndex = -1;
  [sessions enumerateObjectsUsingBlock:^(FPRSessionDetails *session, NSUInteger idx, BOOL *stop) {
    if ([session isVerbose]) {
      firstVerboseSessionIndex = idx;
      *stop = YES;
    }
  }];

  if (firstVerboseSessionIndex > 0) {
    FPRSessionDetails *verboseSession = orderedSessions[firstVerboseSessionIndex];
    [orderedSessions removeObjectAtIndex:firstVerboseSessionIndex];
    [orderedSessions insertObject:verboseSession atIndex:0];
  }

  return [orderedSessions copy];
}
