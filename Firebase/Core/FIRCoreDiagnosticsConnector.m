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

#import "FIRCoreDiagnosticsConnector.h"

#import <FirebaseCoreDiagnosticsInterop/FIRCoreDiagnosticsInterop.h>

#import "FIRAppInternal.h"
#import "FIRDiagnosticsData.h"
#import "FIROptions.h"
#import "FIROptionsInternal.h"
#import "FIRComponentContainer.h"

@implementation FIRCoreDiagnosticsConnector

+ (void)logConfigureCoreWithDefaultPlist {
  id<FIRCoreDiagnosticsInterop> coreDiagnostics =
      FIR_COMPONENT(FIRCoreDiagnosticsInterop, [FIRApp defaultApp].container);
  if (coreDiagnostics) {
    FIRDiagnosticsData *diagnosticsData = [[FIRDiagnosticsData alloc] init];
    [diagnosticsData insertValueIfNotNil:@(YES)
                                  forKey:kFIRCDIsDataCollectionDefaultEnabledKey];
    [diagnosticsData insertValueIfNotNil:[FIRApp firebaseUserAgent]
                                  forKey:kFIRCDFirebaseUserAgentKey];
    [diagnosticsData insertValueIfNotNil:@(FIRConfigTypeCore) forKey:kFIRCDConfigurationTypeKey];
    [coreDiagnostics sendDiagnosticsData:diagnosticsData];
  }
}

+ (void)logConfigureCoreWithOptions:(FIROptions *)options {
  id<FIRCoreDiagnosticsInterop> coreDiagnostics =
  FIR_COMPONENT(FIRCoreDiagnosticsInterop, [FIRApp defaultApp].container);
  if (coreDiagnostics) {
    FIRDiagnosticsData *diagnosticsData = [[FIRDiagnosticsData alloc] init];
    [diagnosticsData insertValueIfNotNil:@(YES)
                                  forKey:kFIRCDIsDataCollectionDefaultEnabledKey];
    [diagnosticsData insertValueIfNotNil:[FIRApp firebaseUserAgent]
                                  forKey:kFIRCDFirebaseUserAgentKey];
    [diagnosticsData insertValueIfNotNil:@(FIRConfigTypeCore) forKey:kFIRCDConfigurationTypeKey];
    [diagnosticsData insertValueIfNotNil:options.googleAppID forKey:kFIRCDGoogleAppIDKey];
    [diagnosticsData insertValueIfNotNil:options.bundleID forKey:kFIRCDBundleIDKey];
    [diagnosticsData insertValueIfNotNil:@(options.usingOptionsFromDefaultPlist)
                                  forKey:kFIRCDUsingOptionsFromDefaultPlistKey];
    [diagnosticsData insertValueIfNotNil:options.libraryVersionID
                                  forKey:kFIRCDLibraryVersionIDKey];
    [coreDiagnostics sendDiagnosticsData:diagnosticsData];
  }
}

@end
