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

#import "FirebasePerformance/Sources/FPRNanoPbUtils.h"

#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#endif

#import "FirebasePerformance/Sources/AppActivity/FPRAppActivityTracker.h"
#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/FIRPerformance+Internal.h"
#import "FirebasePerformance/Sources/FPRDataUtils.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Private.h"

#import "FirebasePerformance/Sources/Gauges/CPU/FPRCPUGaugeData.h"
#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeData.h"

#define BYTES_TO_KB(x) (x / 1024)

static firebase_perf_v1_NetworkRequestMetric_HttpMethod FPRHTTPMethodForString(
    NSString *methodString);
#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
static firebase_perf_v1_NetworkConnectionInfo_MobileSubtype FPRCellularNetworkType(void);
#endif
NSArray<FPRSessionDetails *> *FPRMakeFirstSessionVerbose(NSArray<FPRSessionDetails *> *sessions);

#pragma mark - Nanopb creation utilities

/** Converts the network method string to a value defined in the enum
 *  firebase_perf_v1_NetworkRequestMetric_HttpMethod.
 *  @return Enum value of the method string. If there is no mapping value defined for the method
 * firebase_perf_v1_NetworkRequestMetric_HttpMethod_HTTP_METHOD_UNKNOWN is returned.
 */
static firebase_perf_v1_NetworkRequestMetric_HttpMethod FPRHTTPMethodForString(
    NSString *methodString) {
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

#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
/** Get the current cellular network connection type in
 * firebase_perf_v1_NetworkConnectionInfo_MobileSubtype format.
 *  @return Current cellular network connection type.
 */
static firebase_perf_v1_NetworkConnectionInfo_MobileSubtype FPRCellularNetworkType(void) {
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
      CTRadioAccessTechnologyCDMAEVDORev0 :
          @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_EVDO_0),
      CTRadioAccessTechnologyCDMAEVDORevA :
          @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_EVDO_A),
      CTRadioAccessTechnologyCDMAEVDORevB :
          @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_EVDO_B),
      CTRadioAccessTechnologyeHRPD : @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_EHRPD),
      CTRadioAccessTechnologyLTE : @(firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_LTE)
    };
  });

  NSDictionary<NSString *, NSString *> *radioAccessors =
      FPRNetworkInfo().serviceCurrentRadioAccessTechnology;
  if (radioAccessors.count > 0) {
    NSString *networkString = [radioAccessors.allValues objectAtIndex:0];
    NSNumber *cellularNetworkType = cellularNetworkToMobileSubtype[networkString];
    return cellularNetworkType.intValue;
  }

  return firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_UNKNOWN_MOBILE_SUBTYPE;
}
#endif

#pragma mark - Nanopb decode and encode helper methods

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

StringToStringMap *_Nullable FPREncodeStringToStringMap(NSDictionary *_Nullable dict) {
  StringToStringMap *map = calloc(dict.count, sizeof(StringToStringMap));
  __block NSUInteger index = 0;
  [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
    map[index].key = FPREncodeString(key);
    map[index].value = FPREncodeString(value);
    index++;
  }];
  return map;
}

StringToNumberMap *_Nullable FPREncodeStringToNumberMap(NSDictionary *_Nullable dict) {
  StringToNumberMap *map = calloc(dict.count, sizeof(StringToNumberMap));
  __block NSUInteger index = 0;
  [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *value, BOOL *stop) {
    map[index].key = FPREncodeString(key);
    map[index].value = [value longLongValue];
    map[index].has_value = true;
    index++;
  }];
  return map;
}

firebase_perf_v1_PerfSession *FPREncodePerfSessions(NSArray<FPRSessionDetails *> *sessions,
                                                    NSInteger count) {
  firebase_perf_v1_PerfSession *perfSessions = calloc(count, sizeof(firebase_perf_v1_PerfSession));
  __block NSUInteger perfSessionIndex = 0;

  [sessions enumerateObjectsUsingBlock:^(FPRSessionDetails *_Nonnull session, NSUInteger index,
                                         BOOL *_Nonnull stop) {
    perfSessions[perfSessionIndex].session_id = FPREncodeString(session.sessionId);
    perfSessions[perfSessionIndex].session_verbosity_count = 0;
    if ((session.options & FPRSessionOptionsEvents) ||
        (session.options & FPRSessionOptionsGauges)) {
      perfSessions[perfSessionIndex].session_verbosity_count = 1;
      perfSessions[perfSessionIndex].session_verbosity =
          calloc(perfSessions[perfSessionIndex].session_verbosity_count,
                 sizeof(firebase_perf_v1_SessionVerbosity));
      perfSessions[perfSessionIndex].session_verbosity[0] =
          firebase_perf_v1_SessionVerbosity_GAUGES_AND_SYSTEM_EVENTS;
    }
    perfSessionIndex++;
  }];
  return perfSessions;
}

#pragma mark - Public methods

firebase_perf_v1_PerfMetric FPRGetPerfMetricMessage(NSString *appID) {
  firebase_perf_v1_PerfMetric perfMetricMessage = firebase_perf_v1_PerfMetric_init_default;
  FPRSetApplicationInfo(&perfMetricMessage, FPRGetApplicationInfoMessage());
  perfMetricMessage.application_info.google_app_id = FPREncodeString(appID);

  return perfMetricMessage;
}

firebase_perf_v1_ApplicationInfo FPRGetApplicationInfoMessage(void) {
  firebase_perf_v1_ApplicationInfo appInfoMessage = firebase_perf_v1_ApplicationInfo_init_default;
  firebase_perf_v1_IosApplicationInfo iosAppInfo = firebase_perf_v1_IosApplicationInfo_init_default;
  NSBundle *mainBundle = [NSBundle mainBundle];
  iosAppInfo.bundle_short_version =
      FPREncodeString([mainBundle infoDictionary][@"CFBundleShortVersionString"]);
  iosAppInfo.sdk_version = FPREncodeString([NSString stringWithUTF8String:kFPRSDKVersion]);
  iosAppInfo.network_connection_info.network_type =
      [FPRAppActivityTracker sharedInstance].networkType;
  iosAppInfo.has_network_connection_info = true;
  iosAppInfo.network_connection_info.has_network_type = true;
#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
  if (iosAppInfo.network_connection_info.network_type ==
      firebase_perf_v1_NetworkConnectionInfo_NetworkType_MOBILE) {
    iosAppInfo.network_connection_info.mobile_subtype = FPRCellularNetworkType();
    iosAppInfo.network_connection_info.has_mobile_subtype = true;
  }
#endif
  appInfoMessage.ios_app_info = iosAppInfo;
  appInfoMessage.has_ios_app_info = true;

  NSDictionary<NSString *, NSString *> *attributes =
      [[FIRPerformance sharedInstance].attributes mutableCopy];
  appInfoMessage.custom_attributes_count = (pb_size_t)attributes.count;
  appInfoMessage.custom_attributes =
      (firebase_perf_v1_ApplicationInfo_CustomAttributesEntry *)FPREncodeStringToStringMap(
          attributes);

  return appInfoMessage;
}

firebase_perf_v1_TraceMetric FPRGetTraceMetric(FIRTrace *trace) {
  firebase_perf_v1_TraceMetric traceMetric = firebase_perf_v1_TraceMetric_init_default;
  traceMetric.name = FPREncodeString(trace.name);

  // Set if the trace is an internally created trace.
  traceMetric.is_auto = trace.isInternal;
  traceMetric.has_is_auto = true;

  // Convert the trace duration from seconds to microseconds.
  traceMetric.duration_us = trace.totalTraceTimeInterval * USEC_PER_SEC;
  traceMetric.has_duration_us = true;

  // Convert the start time from seconds to microseconds.
  traceMetric.client_start_time_us = trace.startTimeSinceEpoch * USEC_PER_SEC;
  traceMetric.has_client_start_time_us = true;

  // Filling counters
  NSDictionary<NSString *, NSNumber *> *counters = trace.counters;
  traceMetric.counters_count = (pb_size_t)counters.count;
  traceMetric.counters =
      (firebase_perf_v1_TraceMetric_CountersEntry *)FPREncodeStringToNumberMap(counters);

  // Filling subtraces
  traceMetric.subtraces_count = (pb_size_t)[trace.stages count];
  firebase_perf_v1_TraceMetric *subtraces =
      calloc(traceMetric.subtraces_count, sizeof(firebase_perf_v1_TraceMetric));
  __block NSUInteger subtraceIndex = 0;
  [trace.stages
      enumerateObjectsUsingBlock:^(FIRTrace *_Nonnull stage, NSUInteger idx, BOOL *_Nonnull stop) {
        subtraces[subtraceIndex] = FPRGetTraceMetric(stage);
        subtraceIndex++;
      }];
  traceMetric.subtraces = subtraces;

  // Filling custom attributes
  NSDictionary<NSString *, NSString *> *attributes = [trace.attributes mutableCopy];
  traceMetric.custom_attributes_count = (pb_size_t)attributes.count;
  traceMetric.custom_attributes =
      (firebase_perf_v1_TraceMetric_CustomAttributesEntry *)FPREncodeStringToStringMap(attributes);

  // Filling session details
  NSArray<FPRSessionDetails *> *orderedSessions = FPRMakeFirstSessionVerbose(trace.sessions);
  traceMetric.perf_sessions_count = (pb_size_t)[orderedSessions count];
  traceMetric.perf_sessions =
      FPREncodePerfSessions(orderedSessions, traceMetric.perf_sessions_count);

  return traceMetric;
}

firebase_perf_v1_NetworkRequestMetric FPRGetNetworkRequestMetric(FPRNetworkTrace *trace) {
  firebase_perf_v1_NetworkRequestMetric networkMetric =
      firebase_perf_v1_NetworkRequestMetric_init_default;
  networkMetric.url = FPREncodeString(trace.trimmedURLString);
  networkMetric.http_method = FPRHTTPMethodForString(trace.URLRequest.HTTPMethod);
  networkMetric.has_http_method = true;

  // Convert the start time from seconds to microseconds.
  networkMetric.client_start_time_us = trace.startTimeSinceEpoch * USEC_PER_SEC;
  networkMetric.has_client_start_time_us = true;

  networkMetric.request_payload_bytes = trace.requestSize;
  networkMetric.has_request_payload_bytes = true;
  networkMetric.response_payload_bytes = trace.responseSize;
  networkMetric.has_response_payload_bytes = true;

  networkMetric.http_response_code = trace.responseCode;
  networkMetric.has_http_response_code = true;
  networkMetric.response_content_type = FPREncodeString(trace.responseContentType);

  if (trace.responseError) {
    networkMetric.network_client_error_reason =
        firebase_perf_v1_NetworkRequestMetric_NetworkClientErrorReason_GENERIC_CLIENT_ERROR;
    networkMetric.has_network_client_error_reason = true;
  }

  NSTimeInterval requestTimeUs =
      USEC_PER_SEC *
      [trace timeIntervalBetweenCheckpointState:FPRNetworkTraceCheckpointStateInitiated
                                       andState:FPRNetworkTraceCheckpointStateRequestCompleted];
  if (requestTimeUs > 0) {
    networkMetric.time_to_request_completed_us = requestTimeUs;
    networkMetric.has_time_to_request_completed_us = true;
  }

  NSTimeInterval responseIntiationTimeUs =
      USEC_PER_SEC *
      [trace timeIntervalBetweenCheckpointState:FPRNetworkTraceCheckpointStateInitiated
                                       andState:FPRNetworkTraceCheckpointStateResponseReceived];
  if (responseIntiationTimeUs > 0) {
    networkMetric.time_to_response_initiated_us = responseIntiationTimeUs;
    networkMetric.has_time_to_response_initiated_us = true;
  }

  NSTimeInterval responseCompletedUs =
      USEC_PER_SEC *
      [trace timeIntervalBetweenCheckpointState:FPRNetworkTraceCheckpointStateInitiated
                                       andState:FPRNetworkTraceCheckpointStateResponseCompleted];
  if (responseCompletedUs > 0) {
    networkMetric.time_to_response_completed_us = responseCompletedUs;
    networkMetric.has_time_to_response_completed_us = true;
  }

  // Filling custom attributes
  NSDictionary<NSString *, NSString *> *attributes = [trace.attributes mutableCopy];
  networkMetric.custom_attributes_count = (pb_size_t)attributes.count;
  networkMetric.custom_attributes =
      (firebase_perf_v1_NetworkRequestMetric_CustomAttributesEntry *)FPREncodeStringToStringMap(
          attributes);

  // Filling session details
  NSArray<FPRSessionDetails *> *orderedSessions = FPRMakeFirstSessionVerbose(trace.sessions);
  networkMetric.perf_sessions_count = (pb_size_t)[orderedSessions count];
  networkMetric.perf_sessions =
      FPREncodePerfSessions(orderedSessions, networkMetric.perf_sessions_count);

  return networkMetric;
}

firebase_perf_v1_GaugeMetric FPRGetGaugeMetric(NSArray *gaugeData, NSString *sessionId) {
  firebase_perf_v1_GaugeMetric gaugeMetric = firebase_perf_v1_GaugeMetric_init_default;
  gaugeMetric.session_id = FPREncodeString(sessionId);

  __block NSInteger cpuReadingsCount = 0;
  __block NSInteger memoryReadingsCount = 0;

  firebase_perf_v1_CpuMetricReading *cpuReadings =
      calloc([gaugeData count], sizeof(firebase_perf_v1_CpuMetricReading));
  firebase_perf_v1_IosMemoryReading *memoryReadings =
      calloc([gaugeData count], sizeof(firebase_perf_v1_IosMemoryReading));
  [gaugeData enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    if ([obj isKindOfClass:[FPRCPUGaugeData class]]) {
      FPRCPUGaugeData *gaugeData = (FPRCPUGaugeData *)obj;
      cpuReadings[cpuReadingsCount].client_time_us =
          gaugeData.collectionTime.timeIntervalSince1970 * USEC_PER_SEC;
      cpuReadings[cpuReadingsCount].has_client_time_us = true;
      cpuReadings[cpuReadingsCount].system_time_us = gaugeData.systemTime;
      cpuReadings[cpuReadingsCount].has_system_time_us = true;
      cpuReadings[cpuReadingsCount].user_time_us = gaugeData.userTime;
      cpuReadings[cpuReadingsCount].has_user_time_us = true;
      cpuReadingsCount++;
    }

    if ([obj isKindOfClass:[FPRMemoryGaugeData class]]) {
      FPRMemoryGaugeData *gaugeData = (FPRMemoryGaugeData *)obj;
      memoryReadings[memoryReadingsCount].client_time_us =
          gaugeData.collectionTime.timeIntervalSince1970 * USEC_PER_SEC;
      memoryReadings[memoryReadingsCount].has_client_time_us = true;
      memoryReadings[memoryReadingsCount].used_app_heap_memory_kb =
          (int32_t)BYTES_TO_KB(gaugeData.heapUsed);
      memoryReadings[memoryReadingsCount].has_used_app_heap_memory_kb = true;
      memoryReadings[memoryReadingsCount].free_app_heap_memory_kb =
          (int32_t)BYTES_TO_KB(gaugeData.heapAvailable);
      memoryReadings[memoryReadingsCount].has_free_app_heap_memory_kb = true;
      memoryReadingsCount++;
    }
  }];
  cpuReadings = realloc(cpuReadings, cpuReadingsCount * sizeof(firebase_perf_v1_CpuMetricReading));
  memoryReadings =
      realloc(memoryReadings, memoryReadingsCount * sizeof(firebase_perf_v1_IosMemoryReading));

  gaugeMetric.cpu_metric_readings = cpuReadings;
  gaugeMetric.cpu_metric_readings_count = (pb_size_t)cpuReadingsCount;
  gaugeMetric.ios_memory_readings = memoryReadings;
  gaugeMetric.ios_memory_readings_count = (pb_size_t)memoryReadingsCount;
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
CTTelephonyNetworkInfo *FPRNetworkInfo(void) {
  static CTTelephonyNetworkInfo *networkInfo;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    networkInfo = [[CTTelephonyNetworkInfo alloc] init];
  });
  return networkInfo;
}
#endif

/** Reorders the list of sessions to make sure the first session is verbose if at least one session
 *  in the list is verbose.
 *  @return Ordered list of sessions.
 */
NSArray<FPRSessionDetails *> *FPRMakeFirstSessionVerbose(NSArray<FPRSessionDetails *> *sessions) {
  NSMutableArray<FPRSessionDetails *> *orderedSessions =
      [[NSMutableArray<FPRSessionDetails *> alloc] initWithArray:sessions];

  NSInteger firstVerboseSessionIndex = -1;
  for (int i = 0; i < [sessions count]; i++) {
    if ([sessions[i] isVerbose]) {
      firstVerboseSessionIndex = i;
      break;
    }
  }

  if (firstVerboseSessionIndex > 0) {
    FPRSessionDetails *verboseSession = orderedSessions[firstVerboseSessionIndex];
    [orderedSessions removeObjectAtIndex:firstVerboseSessionIndex];
    [orderedSessions insertObject:verboseSession atIndex:0];
  }

  return [orderedSessions copy];
}

#pragma mark - Nanopb struct fields populating helper methods

void FPRSetApplicationInfo(firebase_perf_v1_PerfMetric *perfMetric,
                           firebase_perf_v1_ApplicationInfo appInfo) {
  perfMetric->application_info = appInfo;
  perfMetric->has_application_info = true;
}

void FPRSetTraceMetric(firebase_perf_v1_PerfMetric *perfMetric,
                       firebase_perf_v1_TraceMetric traceMetric) {
  perfMetric->trace_metric = traceMetric;
  perfMetric->has_trace_metric = true;
}

void FPRSetNetworkRequestMetric(firebase_perf_v1_PerfMetric *perfMetric,
                                firebase_perf_v1_NetworkRequestMetric networkMetric) {
  perfMetric->network_request_metric = networkMetric;
  perfMetric->has_network_request_metric = true;
}

void FPRSetGaugeMetric(firebase_perf_v1_PerfMetric *perfMetric,
                       firebase_perf_v1_GaugeMetric gaugeMetric) {
  perfMetric->gauge_metric = gaugeMetric;
  perfMetric->has_gauge_metric = true;
}

void FPRSetApplicationProcessState(firebase_perf_v1_PerfMetric *perfMetric,
                                   firebase_perf_v1_ApplicationProcessState state) {
  perfMetric->application_info.application_process_state = state;
  perfMetric->application_info.has_application_process_state = true;
}
