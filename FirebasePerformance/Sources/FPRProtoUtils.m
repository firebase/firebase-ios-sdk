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

NSMutableDictionary<NSString*, NSString*> *FPRDecodeCustomAttributes(struct _firebase_perf_v1_ApplicationInfo_CustomAttributesEntry *customAttributes, NSInteger count) {
  NSMutableDictionary<NSString*, NSString*> *dict = [NSMutableDictionary dictionary];
  for (int i = 0; i < count; i++) {
    NSString *key = FPRDecodeString(customAttributes[i].key);
    NSString *value = FPRDecodeString(customAttributes[i].value);
    dict[key] = value;
  }
  return dict;
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
  if (iosAppInfo.network_connection_info.network_type ==
      firebase_perf_v1_NetworkConnectionInfo_NetworkType_MOBILE) {
    iosAppInfo.network_connection_info.mobile_subtype = FPRCellularNetworkType();
  }
#endif
  appInfoMessage.ios_app_info = iosAppInfo;

  NSDictionary<NSString *, NSString *> *attributes = [[FIRPerformance sharedInstance].attributes mutableCopy];
  struct _firebase_perf_v1_ApplicationInfo_CustomAttributesEntry *custom_attributes = calloc(attributes.count, sizeof(firebase_perf_v1_ApplicationInfo_CustomAttributesEntry));
  appInfoMessage.custom_attributes_count = attributes.count;
  __block NSUInteger index = 0;
  [attributes enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
    custom_attributes[index].key = FPREncodeString(key);
    custom_attributes[index].value = FPREncodeString(value);
    index++;
  }];
  appInfoMessage.custom_attributes = custom_attributes;
  
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

FPRMSGNetworkRequestMetric *FPRGetNetworkRequestMetric(FPRNetworkTrace *trace) {
  if (trace == nil) {
    return nil;
  }

  // If there is no valid status code, do not send the event to backend.
  if (!trace.hasValidResponseCode) {
    return nil;
  }

  FPRMSGNetworkRequestMetric *networkMetric = [FPRMSGNetworkRequestMetric message];
  networkMetric.URL = trace.trimmedURLString;
  networkMetric.HTTPMethod = FPRHTTPMethodForString(trace.URLRequest.HTTPMethod);

  // Convert the start time from seconds to microseconds.
  networkMetric.clientStartTimeUs = trace.startTimeSinceEpoch * USEC_PER_SEC;

  networkMetric.requestPayloadBytes = trace.requestSize;
  networkMetric.responsePayloadBytes = trace.responseSize;

  networkMetric.HTTPResponseCode = trace.responseCode;
  networkMetric.responseContentType = trace.responseContentType;

  if (trace.responseError) {
    networkMetric.networkClientErrorReason =
        FPRMSGNetworkRequestMetric_NetworkClientErrorReason_GenericClientError;
  }

  NSTimeInterval requestTimeUs =
      USEC_PER_SEC *
      [trace timeIntervalBetweenCheckpointState:FPRNetworkTraceCheckpointStateInitiated
                                       andState:FPRNetworkTraceCheckpointStateRequestCompleted];
  if (requestTimeUs > 0) {
    networkMetric.timeToRequestCompletedUs = requestTimeUs;
  }

  NSTimeInterval responseIntiationTimeUs =
      USEC_PER_SEC *
      [trace timeIntervalBetweenCheckpointState:FPRNetworkTraceCheckpointStateInitiated
                                       andState:FPRNetworkTraceCheckpointStateResponseReceived];
  if (responseIntiationTimeUs > 0) {
    networkMetric.timeToResponseInitiatedUs = responseIntiationTimeUs;
  }

  NSTimeInterval responseCompletedUs =
      USEC_PER_SEC *
      [trace timeIntervalBetweenCheckpointState:FPRNetworkTraceCheckpointStateInitiated
                                       andState:FPRNetworkTraceCheckpointStateResponseCompleted];
  if (responseCompletedUs > 0) {
    networkMetric.timeToResponseCompletedUs = responseCompletedUs;
  }

  networkMetric.customAttributes = [trace.attributes mutableCopy];

  // Fillin session details
  NSArray<FPRSessionDetails *> *orderedSessions = FPRMakeFirstSessionVerbose(trace.sessions);
  networkMetric.perfSessionsArray = [[NSMutableArray<FPRMSGPerfSession *> alloc] init];
  [orderedSessions enumerateObjectsUsingBlock:^(FPRSessionDetails *_Nonnull session,
                                                NSUInteger index, BOOL *_Nonnull stop) {
    FPRMSGPerfSession *perfSession = [FPRMSGPerfSession message];
    perfSession.sessionId = session.sessionId;
    perfSession.sessionVerbosityArray = [GPBEnumArray array];
    if ((session.options & FPRSessionOptionsEvents) ||
        (session.options & FPRSessionOptionsGauges)) {
      [perfSession.sessionVerbosityArray addValue:FPRMSGSessionVerbosity_GaugesAndSystemEvents];
    }
    [networkMetric.perfSessionsArray addObject:perfSession];
  }];

  return networkMetric;
}

FPRMSGGaugeMetric *FPRGetGaugeMetric(NSArray *gaugeData, NSString *sessionId) {
  if (gaugeData == nil || gaugeData.count == 0) {
    return nil;
  }

  if (sessionId == nil || sessionId.length == 0) {
    return nil;
  }

  FPRMSGGaugeMetric *gaugeMetric = [FPRMSGGaugeMetric message];
  gaugeMetric.sessionId = sessionId;
  NSMutableArray<FPRMSGCpuMetricReading *> *cpuReadings =
      [[NSMutableArray<FPRMSGCpuMetricReading *> alloc] init];
  NSMutableArray<FPRMSGIosMemoryReading *> *memoryReadings =
      [[NSMutableArray<FPRMSGIosMemoryReading *> alloc] init];
  [gaugeData enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    if ([obj isKindOfClass:[FPRCPUGaugeData class]]) {
      FPRCPUGaugeData *gaugeData = (FPRCPUGaugeData *)obj;
      FPRMSGCpuMetricReading *cpuReading = [FPRMSGCpuMetricReading message];
      cpuReading.clientTimeUs = gaugeData.collectionTime.timeIntervalSince1970 * USEC_PER_SEC;
      cpuReading.systemTimeUs = gaugeData.systemTime;
      cpuReading.userTimeUs = gaugeData.userTime;
      [cpuReadings addObject:cpuReading];
    }

    if ([obj isKindOfClass:[FPRMemoryGaugeData class]]) {
      FPRMemoryGaugeData *gaugeData = (FPRMemoryGaugeData *)obj;
      FPRMSGIosMemoryReading *memoryReading = [FPRMSGIosMemoryReading message];
      memoryReading.clientTimeUs = gaugeData.collectionTime.timeIntervalSince1970 * USEC_PER_SEC;
      memoryReading.usedAppHeapMemoryKb = (int32_t)BYTES_TO_KB(gaugeData.heapUsed);
      memoryReading.freeAppHeapMemoryKb = (int32_t)BYTES_TO_KB(gaugeData.heapAvailable);
      [memoryReadings addObject:memoryReading];
    }
  }];
  gaugeMetric.cpuMetricReadingsArray = cpuReadings;
  gaugeMetric.iosMemoryReadingsArray = memoryReadings;
  return gaugeMetric;
}

firebase_perf_v1_ApplicationProcessState FPRApplicationProcessState(FPRTraceState state) {
  FPRMSGApplicationProcessState processState =
      FPRMSGApplicationProcessState_ApplicationProcessStateUnknown;
  switch (state) {
    case FPRTraceStateForegroundOnly:
      processState = FPRMSGApplicationProcessState_Foreground;
      break;

    case FPRTraceStateBackgroundOnly:
      processState = FPRMSGApplicationProcessState_Background;
      break;

    case FPRTraceStateBackgroundAndForeground:
      processState = FPRMSGApplicationProcessState_ForegroundBackground;
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
static GPBStringInt64Dictionary *FPRGetProtoCounterForDictionary(
    NSDictionary<NSString *, NSNumber *> *dictionary) {
  GPBStringInt64Dictionary *counterDictionary = [[GPBStringInt64Dictionary alloc] init];
  [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSNumber *_Nonnull value,
                                                  BOOL *_Nonnull stop) {
    [counterDictionary setInt64:[value longLongValue] forKey:key];
  }];

  return counterDictionary;
}

/** Converts the network method string to a value defined in the enum
 *  FPRMSGNetworkRequestMetric_HttpMethod.
 *  @return Enum value of the method string. If there is no mapping value defined for the method
 *      string FPRMSGNetworkRequestMetric_HttpMethod_HTTPMethodUnknown is returned.
 */
static firebase_perf_v1_NetworkRequestMetric_HttpMethod FPRHTTPMethodForString(NSString *methodString) {
  static NSDictionary<NSString *, NSNumber *> *HTTPToFPRNetworkTraceMethod;
  static dispatch_once_t onceToken = 0;
  dispatch_once(&onceToken, ^{
    HTTPToFPRNetworkTraceMethod = @{
      @"GET" : @(FPRMSGNetworkRequestMetric_HttpMethod_Get),
      @"POST" : @(FPRMSGNetworkRequestMetric_HttpMethod_Post),
      @"PUT" : @(FPRMSGNetworkRequestMetric_HttpMethod_Put),
      @"DELETE" : @(FPRMSGNetworkRequestMetric_HttpMethod_Delete),
      @"HEAD" : @(FPRMSGNetworkRequestMetric_HttpMethod_Head),
      @"PATCH" : @(FPRMSGNetworkRequestMetric_HttpMethod_Patch),
      @"OPTIONS" : @(FPRMSGNetworkRequestMetric_HttpMethod_Options),
      @"TRACE" : @(FPRMSGNetworkRequestMetric_HttpMethod_Trace),
      @"CONNECT" : @(FPRMSGNetworkRequestMetric_HttpMethod_Connect),
    };
  });

  NSNumber *HTTPMethod = HTTPToFPRNetworkTraceMethod[methodString];
  if (HTTPMethod == nil) {
    return FPRMSGNetworkRequestMetric_HttpMethod_HTTPMethodUnknown;
  }
  return HTTPMethod.intValue;
}

/** Get the current network connection type in NetworkConnectionInfo_NetworkType format.
 *  @return Current network connection type.
 */
static firebase_perf_v1_NetworkConnectionInfo_NetworkType FPRNetworkConnectionInfoNetworkType() {
  FPRMSGNetworkConnectionInfo_NetworkType networkType =
      FPRMSGNetworkConnectionInfo_NetworkType_None;

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
      networkType = FPRMSGNetworkConnectionInfo_NetworkType_Mobile;
    } else {
      networkType = FPRMSGNetworkConnectionInfo_NetworkType_Wifi;
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
      CTRadioAccessTechnologyGPRS : @(FPRMSGNetworkConnectionInfo_MobileSubtype_Gprs),
      CTRadioAccessTechnologyEdge : @(FPRMSGNetworkConnectionInfo_MobileSubtype_Edge),
      CTRadioAccessTechnologyWCDMA : @(FPRMSGNetworkConnectionInfo_MobileSubtype_Cdma),
      CTRadioAccessTechnologyHSDPA : @(FPRMSGNetworkConnectionInfo_MobileSubtype_Hsdpa),
      CTRadioAccessTechnologyHSUPA : @(FPRMSGNetworkConnectionInfo_MobileSubtype_Hsupa),
      CTRadioAccessTechnologyCDMA1x : @(FPRMSGNetworkConnectionInfo_MobileSubtype_Cdma),
      CTRadioAccessTechnologyCDMAEVDORev0 : @(FPRMSGNetworkConnectionInfo_MobileSubtype_Evdo0),
      CTRadioAccessTechnologyCDMAEVDORevA : @(FPRMSGNetworkConnectionInfo_MobileSubtype_EvdoA),
      CTRadioAccessTechnologyCDMAEVDORevB : @(FPRMSGNetworkConnectionInfo_MobileSubtype_EvdoB),
      CTRadioAccessTechnologyeHRPD : @(FPRMSGNetworkConnectionInfo_MobileSubtype_Ehrpd),
      CTRadioAccessTechnologyLTE : @(FPRMSGNetworkConnectionInfo_MobileSubtype_Lte)
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
