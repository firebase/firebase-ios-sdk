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
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockNetworkClient.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockReportUploader.h"

#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"

@interface FIRCLSMockReportManager () {
  FIRCLSMockReportUploader *_uploader;
}

@end

@implementation FIRCLSMockReportManager

// these have to be synthesized, to override the pre-existing method
@synthesize bundleIdentifier;

- (instancetype)initWithFileManager:(FIRCLSFileManager *)fileManager
                      installations:(FIRInstallations *)installations
                          analytics:(id<FIRAnalyticsInterop>)analytics
                        googleAppID:(NSString *)googleAppID
                        dataArbiter:(FIRCLSDataCollectionArbiter *)dataArbiter
                    googleTransport:(GDTCORTransport *)googleTransport
                         appIDModel:(FIRCLSApplicationIdentifierModel *)appIDModel
                           settings:(FIRCLSSettings *)settings {
  self = [super initWithFileManager:fileManager
                      installations:installations
                          analytics:analytics
                        googleAppID:googleAppID
                        dataArbiter:dataArbiter
                    googleTransport:googleTransport
                         appIDModel:appIDModel
                           settings:settings];
  if (!self) {
    return nil;
  }

  _uploader = [[FIRCLSMockReportUploader alloc] initWithQueue:self.operationQueue
                                                     delegate:self
                                                   dataSource:self
                                                       client:self.networkClient
                                                  fileManager:fileManager
                                                    analytics:analytics];

  return self;
}

- (FIRCLSNetworkClient *)clientWithOperationQueue:(NSOperationQueue *)queue {
  return [[FIRCLSMockNetworkClient alloc] initWithQueue:queue
                                            fileManager:self.fileManager
                                               delegate:(id<FIRCLSNetworkClientDelegate>)self];
}

- (FIRCLSReportUploader *)uploader {
  return _uploader;
}

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
