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

#import "Crashlytics/Crashlytics/Settings/FIRCLSSettingsManager.h"

#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionToken.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSDefines.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInstallIdentifierModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"
#import "Crashlytics/Crashlytics/Settings/Models/FIRCLSApplicationIdentifierModel.h"
#import "Crashlytics/Crashlytics/Settings/Operations/FIRCLSDownloadAndSaveSettingsOperation.h"
#import "Crashlytics/Shared/FIRCLSConstants.h"
#import "Crashlytics/Shared/FIRCLSNetworking/FIRCLSFABNetworkClient.h"
#import "Crashlytics/Shared/FIRCLSNetworking/FIRCLSURLBuilder.h"

@interface FIRCLSSettingsManager () <FIRCLSDownloadAndSaveSettingsOperationDelegate>

@property(nonatomic, strong) FIRCLSApplicationIdentifierModel *appIDModel;
@property(nonatomic, strong) FIRCLSInstallIdentifierModel *installIDModel;

@property(nonatomic, strong) FIRCLSSettings *settings;

@property(nonatomic, strong) FIRCLSFileManager *fileManager;

@property(nonatomic) NSDictionary *configuration;
@property(nonatomic) NSDictionary *defaultConfiguration;
@property(nonatomic, copy) NSString *googleAppID;
@property(nonatomic, copy) NSDictionary *kitVersionsByKitBundleIdentifier;
@property(nonatomic, readonly) FIRCLSFABNetworkClient *networkClient;

@end

@implementation FIRCLSSettingsManager

- (instancetype)initWithAppIDModel:(FIRCLSApplicationIdentifierModel *)appIDModel
                    installIDModel:(FIRCLSInstallIdentifierModel *)installIDModel
                          settings:(FIRCLSSettings *)settings
                       fileManager:(FIRCLSFileManager *)fileManager
                       googleAppID:(NSString *)googleAppID {
  self = [super init];
  if (!self) {
    return nil;
  }

  _appIDModel = appIDModel;
  _installIDModel = installIDModel;
  _settings = settings;
  _fileManager = fileManager;
  _googleAppID = googleAppID;

  _networkClient = [[FIRCLSFABNetworkClient alloc] initWithQueue:nil];

  return self;
}

- (void)beginSettingsWithGoogleAppId:(NSString *)googleAppID
                               token:(FIRCLSDataCollectionToken *)token
                   waitForCompletion:(BOOL)waitForCompletion {
  NSParameterAssert(googleAppID);

  self.googleAppID = googleAppID;

  // This map helps us determine what versions of the SDK
  // are out there. We're keeping the Fabric value in there for
  // backwards compatibility
  // TODO(b/141747635)
  self.kitVersionsByKitBundleIdentifier = @{
    FIRCLSApplicationGetSDKBundleID() : FIRCLSSDKVersion(),
  };

  [self beginSettingsDownload:token waitForCompletion:waitForCompletion];
}

#pragma mark Helper methods

/**
 * Makes a settings download request. If the request fails, the error is handled silently (with a
 * log statement).
 */
- (void)beginSettingsDownload:(FIRCLSDataCollectionToken *)token
            waitForCompletion:(BOOL)waitForCompletion {
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

  FIRCLSDownloadAndSaveSettingsOperation *operation = nil;
  operation = [[FIRCLSDownloadAndSaveSettingsOperation alloc]
        initWithGoogleAppID:self.googleAppID
                   delegate:self
                settingsURL:self.settingsURL
      settingsDirectoryPath:self.fileManager.settingsDirectoryPath
           settingsFilePath:self.fileManager.settingsFilePath
             installIDModel:self.installIDModel
              networkClient:self.networkClient
                      token:token];

  if (waitForCompletion) {
    operation.asyncCompletion = ^(NSError *error) {
      dispatch_semaphore_signal(semaphore);
    };
  }

  [operation startWithToken:token];

  if (waitForCompletion) {
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
  }
}

- (void)finishNetworkingSession {
  [self.networkClient invalidateAndCancel];
}

#pragma mark FIRCLSDownloadAndSaveSettingsOperationDelegate methods

- (void)operation:(FIRCLSDownloadAndSaveSettingsOperation *)operation
    didDownloadAndSaveSettingsWithError:(nullable NSError *)error {
  if (error) {
    NSString *message = @"Failed to download settings.";
    if (error.userInfo && [error.userInfo objectForKey:@"status_code"] &&
        [[error.userInfo objectForKey:@"status_code"]
            isEqualToNumber:[NSNumber numberWithInt:404]]) {
      NSString *debugHint = @"If this is your first time launching the app, make sure you have "
                            @"enabled Crashlytics in the Firebase Console.";
      message = [NSString stringWithFormat:@"%@ %@", message, debugHint];
    }
    FIRCLSErrorLog(@"%@ %@", message, error);
    [self finishNetworkingSession];
    return;
  }

  FIRCLSDebugLog(@"Settings downloaded successfully");

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:self.googleAppID currentTimestamp:currentTimestamp];

  // we're all set!
  [self finishNetworkingSession];
}

- (NSURL *)settingsURL {
  // GET
  // /spi/v2/platforms/:platform/apps/:identifier/settings?build_version=1234&display_version=abc&instance=xyz&source=1
  FIRCLSURLBuilder *url = [FIRCLSURLBuilder URLWithBase:FIRCLSSettingsEndpoint];

  [url appendComponent:@"/spi/v2/platforms/"];
  [url escapeAndAppendComponent:self.appIDModel.platform];
  [url appendComponent:@"/gmp/"];
  [url escapeAndAppendComponent:self.googleAppID];
  [url appendComponent:@"/settings"];

  [url appendValue:self.appIDModel.buildVersion forQueryParam:@"build_version"];
  [url appendValue:self.appIDModel.displayVersion forQueryParam:@"display_version"];
  [url appendValue:self.appIDModel.buildInstanceID forQueryParam:@"instance"];
  [url appendValue:@(self.appIDModel.installSource) forQueryParam:@"source"];
  // TODO: find the right param name for KitVersions and add them here
  return url.URL;
}

@end
