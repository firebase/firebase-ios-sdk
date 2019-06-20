/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

#import "FIRCoreDiagnosticsData.h"

NS_ASSUME_NONNULL_BEGIN

/** An SDK service identifier. */
static NSString *const kFIRServiceAdMob = @"AdMob";

/** An SDK service identifier. */
static NSString *const kFIRServiceAuth = @"Auth";

/** An SDK service identifier. */
static NSString *const kFIRServiceAuthUI = @"AuthUI";

/** An SDK service identifier. */
static NSString *const kFIRServiceCrash = @"Crash";

/** An SDK service identifier. */
static NSString *const kFIRServiceDatabase = @"Database";

/** An SDK service identifier. */
static NSString *const kFIRServiceDynamicLinks = @"DynamicLinks";

/** An SDK service identifier. */
static NSString *const kFIRServiceFirestore = @"Firestore";

/** An SDK service identifier. */
static NSString *const kFIRServiceFunctions = @"Functions";

/** An SDK service identifier. */
static NSString *const kFIRServiceInstanceID = @"InstanceID";

/** An SDK service identifier. */
static NSString *const kFIRServiceInvites = @"Invites";

/** An SDK service identifier. */
static NSString *const kFIRServiceMessaging = @"Messaging";

/** An SDK service identifier. */
static NSString *const kFIRServiceMeasurement = @"Measurement";

/** An SDK service identifier. */
static NSString *const kFIRServicePerformance = @"Performance";

/** An SDK service identifier. */
static NSString *const kFIRServiceRemoteConfig = @"RemoteConfig";

/** An SDK service identifier. */
static NSString *const kFIRServiceStorage = @"Storage";

/** An SDK service identifier. */
static NSString *const kGGLServiceAnalytics = @"Analytics";

/** An SDK service identifier. */
static NSString *const kGGLServiceSignIn = @"SignIn";

/** A dictionary key for the diagnostics configuration. */
static NSString *const kFIRAppDiagnosticsConfigurationTypeKey = @"FIRAppDiagnosticsConfigurationTypeKey";

/** A dictionary key for the FIRApp context. */
static NSString *const kFIRAppDiagnosticsFIRAppKey = @"FIRAppDiagnosticsFIRAppKey";

/** A dictionary key for the SDK name. */
static NSString *const kFIRAppDiagnosticsSDKNameKey = @"FIRAppDiagnosticsSDKNameKey";

/** A dictionary key for the SDK version. */
static NSString *const kFIRAppDiagnosticsSDKVersionKey = @"FIRAppDiagnosticsSDKVersionKey";

/** Allows the interoperation of FirebaseCore and FirebaseCoreDiagnostics. */
@protocol FIRCoreDiagnosticsInterop <NSObject>

/** Sends the given diagnostics data.
 *
 * @param diagnosticsData The diagnostics data object to send.
 */
+ (void)sendDiagnosticsData:(id<FIRCoreDiagnosticsData>)diagnosticsData;

@end

/** The class that implements this interop protocol. Unforunately, the components framework can't
 * be used because of a cyclical dependency issue.
 */
extern Class<FIRCoreDiagnosticsInterop> FIRCoreDiagnosticsImplementation;

NS_ASSUME_NONNULL_END
