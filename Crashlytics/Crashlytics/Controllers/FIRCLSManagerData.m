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

#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"

#import "Crashlytics/Crashlytics/Components/FIRCLSApplication.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSExecutionIdentifierModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInstallIdentifierModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"
#import "Crashlytics/Crashlytics/Private/FIRCLSOnDemandModel_Private.h"
#import "Crashlytics/Crashlytics/Settings/Models/FIRCLSApplicationIdentifierModel.h"

@implementation FIRCLSManagerData

- (instancetype)initWithGoogleAppID:(NSString *)googleAppID
                    googleTransport:(GDTCORTransport *)googleTransport
                      installations:(FIRInstallations *)installations
                          analytics:(nullable id<FIRAnalyticsInterop>)analytics
                        fileManager:(FIRCLSFileManager *)fileManager
                        dataArbiter:(FIRCLSDataCollectionArbiter *)dataArbiter
                           settings:(FIRCLSSettings *)settings
                      onDemandModel:(FIRCLSOnDemandModel *)onDemandModel {
  self = [super init];
  if (!self) {
    return nil;
  }

  _googleAppID = googleAppID;
  _googleTransport = googleTransport;
  _installations = installations;
  _analytics = analytics;
  _fileManager = fileManager;
  _dataArbiter = dataArbiter;
  _settings = settings;
  _onDemandModel = onDemandModel;

  _appIDModel = [[FIRCLSApplicationIdentifierModel alloc] init];
  _installIDModel = [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:installations];
  _executionIDModel = [[FIRCLSExecutionIdentifierModel alloc] init];

  NSString *sdkBundleID = FIRCLSApplicationGetSDKBundleID();
  _operationQueue = [NSOperationQueue new];
  [_operationQueue setMaxConcurrentOperationCount:1];
  [_operationQueue setName:[sdkBundleID stringByAppendingString:@".work-queue"]];

  _dispatchQueue = dispatch_queue_create("com.google.firebase.crashlytics.startup", 0);
  _operationQueue.underlyingQueue = _dispatchQueue;

  return self;
}

@end
