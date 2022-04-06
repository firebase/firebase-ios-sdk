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

#import "FIRTrace.h"

/**
 * This class allows you to configure the Firebase Performance Reporting SDK. It also provides the
 * interfaces to create timers and enable or disable automatic metrics capture.
 *
 * This SDK uses a Firebase Installations ID to identify the app instance and periodically sends
 * data to the Firebase backend (see `Installations.installationID(completion:)`).
 * To stop this periodic sync, call `Installations.delete(completion:)` and
 * either disable this SDK or set Performance.dataCollectionEnabled to false.
 */
NS_EXTENSION_UNAVAILABLE("FirebasePerformance does not support app extensions at this time.")
NS_SWIFT_NAME(Performance)
@interface FIRPerformance : NSObject

/**
 * Controls the capture of performance data. When this value is set to NO, none of the performance
 * data will sent to the server. Default is true.
 *
 * This setting is persisted, and is applied on future invocations of your application. Once
 * explicitly set, it overrides any settings in your Info.plist.
 */
@property(nonatomic, assign, getter=isDataCollectionEnabled) BOOL dataCollectionEnabled;

/**
 * Controls the instrumentation of the app to capture performance data. Setting this value to false
 * has immediate effect only if it is done so before calling FirebaseApp.configure(). Otherwise it
 * takes effect on the next app start.
 *
 * If set to false, the app will not be instrumented to collect performance
 * data (in scenarios like `app_start`, networking monitoring). Default is true.
 *
 * This setting is persisted, and is applied on future invocations of your application. Once
 * explicitly set, it overrides any settings in your `Info.plist`.
 */
@property(nonatomic, assign, getter=isInstrumentationEnabled) BOOL instrumentationEnabled;

/** @return The shared instance. */
+ (nonnull instancetype)sharedInstance NS_SWIFT_NAME(sharedInstance());

/**
 * Creates an instance of Trace after creating the shared instance of Performance. The trace
 * will automatically be started on a successful creation of the instance. The `name` of the trace
 * cannot be an empty string.
 *
 * @param name The name of the trace.
 * @return The Trace object.
 */
+ (nullable FIRTrace *)startTraceWithName:(nonnull NSString *)name NS_SWIFT_NAME(startTrace(name:));

/**
 * Creates an instance of Trace. This API does not start the trace. To start the trace, use the
 * `start()` method on the returned Trace object. The `name` cannot be an empty string.
 *
 * @param name The name of the Trace.
 * @return The FIRTrace object.
 */
- (nullable FIRTrace *)traceWithName:(nonnull NSString *)name NS_SWIFT_NAME(trace(name:));

@end
