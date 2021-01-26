// Copyright 2019 Google
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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockReportManager.h"

#import "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSExistingReportManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockReportUploader.h"

#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"

@implementation FIRCLSMockReportManager

- (BOOL)startCrashReporterWithProfilingMark:(FIRCLSProfileMark)mark
                                     report:(FIRCLSInternalReport *)report {
  NSLog(@"Crash Reporting system disabled for testing");

  return YES;
}

- (BOOL)installCrashReportingHandlers:(FIRCLSContextInitData *)initData {
  return YES;
  // This actually installs crash handlers, there is no need to do that during testing.
}

- (void)crashReportingSetupCompleted {
  // This stuff does operations on the main thread, which we don't want during tests.
}

@end
