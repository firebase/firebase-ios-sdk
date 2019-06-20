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
FOUNDATION_EXTERN NSString *const kFIRServiceAdMob;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kFIRServiceAuth;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kFIRServiceAuthUI;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kFIRServiceCrash;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kFIRServiceDatabase;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kFIRServiceDynamicLinks;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kFIRServiceFirestore;
 
/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kFIRServiceFunctions;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kFIRServiceInstanceID;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kFIRServiceInvites;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kFIRServiceMessaging;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kFIRServiceMeasurement;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kFIRServicePerformance;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kFIRServiceRemoteConfig;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kFIRServiceStorage;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kGGLServiceAnalytics;

/** An SDK service identifier. */
FOUNDATION_EXTERN NSString *const kGGLServiceSignIn;

/** A dictionary key for the diagnostics configuration. */
FOUNDATION_EXTERN NSString *const kFIRAppDiagnosticsConfigurationTypeKey;

/** A dictionary key for the FIRApp context. */
FOUNDATION_EXTERN NSString *const kFIRAppDiagnosticsFIRAppKey;

/** A dictionary key for the SDK name. */
FOUNDATION_EXTERN NSString *const kFIRAppDiagnosticsSDKNameKey;

/** A dictionary key for the SDK version. */
FOUNDATION_EXTERN NSString *const kFIRAppDiagnosticsSDKVersionKey;

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
FOUNDATION_EXTERN Class<FIRCoreDiagnosticsInterop> FIRCoreDiagnosticsImplementation;

NS_ASSUME_NONNULL_END
