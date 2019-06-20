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

// Interop libraries should not have .m files in the general case. Given the unique nature of the
// dependency structure between FirebaseCore and FirebaseCoreDiagnostics, a .m was needed to break
// a kind of cyclical dependency. FirebaseCoreDiagnostics is listed in Cocoapods as a hard dep
// but is implemented as a weak dep. FirebaseCoreDiagnostics has no dependency on FirebaseCore.
// FirebaseCoreDiagnosticsInterop declares an extern Class<FIRCoreDiagnosticsInterop> variable
// (just below) that was implemented in FirebaseCore. Since FirebaseCoreDiagnostics has no (and
// cannot have) a dependency on FirebaseCore, it was unable to link. This implementation is the
// result. Other shared variables have also been moved here to save binary size that would have
// arisen from having all these variables declared as static in the interop header.

 #import "Public/FIRCoreDiagnosticsInterop.h"

Class<FIRCoreDiagnosticsInterop> FIRCoreDiagnosticsImplementation;

NSString *const kFIRServiceAdMob = @"AdMob";
NSString *const kFIRServiceAuth = @"Auth";
NSString *const kFIRServiceAuthUI = @"AuthUI";
NSString *const kFIRServiceCrash = @"Crash";
NSString *const kFIRServiceDatabase = @"Database";
NSString *const kFIRServiceDynamicLinks = @"DynamicLinks";
NSString *const kFIRServiceFirestore = @"Firestore";
NSString *const kFIRServiceFunctions = @"Functions";
NSString *const kFIRServiceInstanceID = @"InstanceID";
NSString *const kFIRServiceInvites = @"Invites";
NSString *const kFIRServiceMessaging = @"Messaging";
NSString *const kFIRServiceMeasurement = @"Measurement";
NSString *const kFIRServicePerformance = @"Performance";
NSString *const kFIRServiceRemoteConfig = @"RemoteConfig";
NSString *const kFIRServiceStorage = @"Storage";
NSString *const kGGLServiceAnalytics = @"Analytics";
NSString *const kGGLServiceSignIn = @"SignIn";
NSString *const kFIRAppDiagnosticsConfigurationTypeKey = @"FIRAppDiagnosticsConfigurationTypeKey";
NSString *const kFIRAppDiagnosticsFIRAppKey = @"FIRAppDiagnosticsFIRAppKey";
NSString *const kFIRAppDiagnosticsSDKNameKey = @"FIRAppDiagnosticsSDKNameKey";
NSString *const kFIRAppDiagnosticsSDKVersionKey = @"FIRAppDiagnosticsSDKVersionKey";
