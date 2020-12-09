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

#import "FirebasePerformance/Sources/Public/FIRTrace.h"

#import "FirebasePerformance/Sources/FPRConfiguration.h"
#import "FirebasePerformance/Sources/Gauges/FPRGaugeManager.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"

/** NSError codes for FPRClient related errors */
typedef NS_ENUM(NSInteger, FPRClientErrorCode) {
  // Generic Error.
  FPRClientErrorCodeUnknown,

  // Error starting the client.
  FPRClientErrorCodeStartupError
};

/** This class is not exposed to the public and internally provides the primary entry point into
 *  the Firebase Performance module's functionality.
 */
@interface FPRClient : NSObject

/** YES if SDK is configured, otherwise NO. */
@property(nonatomic, getter=isConfigured, readonly) BOOL configured;

/** YES if methods have been swizzled, NO otherwise. */
@property(nonatomic, getter=isSwizzled) BOOL swizzled;

/** Accesses the singleton instance. All Firebase Performance methods should be managed via this
 *  shared instance.
 *  @return Reference to the shared object if successful; <code>nil</code> if not.
 */
+ (nonnull FPRClient *)sharedInstance;

/** Enables performance reporting. This installs auto instrumentation and configures metric
 *  uploading.
 *
 *  @param config Configures perf reporting behavior.
 *  @param error Populated with an NSError instance on failure.
 *  @return <code>YES</code> if successful; <code>NO</code> if not.
 */
- (BOOL)startWithConfiguration:(nonnull FPRConfiguration *)config
                         error:(NSError *__autoreleasing _Nullable *_Nullable)error;

/** Logs a trace event.
 *
 *  @param trace Trace event that needs to be logged to Google Data Transport.
 */
- (void)logTrace:(nonnull FIRTrace *)trace;

/** Logs a network trace event.
 *
 *  @param trace Network trace event that needs to be logged to Google Data Transport.
 */
- (void)logNetworkTrace:(nonnull FPRNetworkTrace *)trace;

/** Logs a gauge metric event.
 *
 *  @param gaugeData Gauge metric event that needs to be logged to Google Data Transport.
 *  @param sessionId SessionID with which the gauge data will be logged.
 */
- (void)logGaugeMetric:(nonnull NSArray *)gaugeData forSessionId:(nonnull NSString *)sessionId;

/** Checks if the instrumentation of the app is enabled. If enabled, setup the instrumentation. */
- (void)checkAndStartInstrumentation;

/** Unswizzles any existing methods that have been instrumented and stops automatic instrumentation
 *  for all future app starts unless explicitly enabled.
 */
- (void)disableInstrumentation;

@end
