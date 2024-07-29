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

#import "Crashlytics/Crashlytics/Models/FIRCLSInstallIdentifierModel.h"

#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"

#import "Crashlytics/Crashlytics/FIRCLSUserDefaults/FIRCLSUserDefaults.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"
#import "Crashlytics/Shared/FIRCLSByteUtility.h"
#import "Crashlytics/Shared/FIRCLSUUID.h"

static NSString *const FIRCLSInstallationUUIDKey = @"com.crashlytics.iuuid";
static NSString *const FIRCLSInstallationIIDHashKey = @"com.crashlytics.install.iid";

// Legacy key that is automatically removed
static NSString *const FIRCLSInstallationADIDKey = @"com.crashlytics.install.adid";

static unsigned long long FIRCLSInstallationsWaitTime = 10 * NSEC_PER_SEC;

@interface FIRCLSInstallIdentifierModel ()

@property(nonatomic, copy) NSString *installID;

@property(nonatomic, readonly) FIRInstallations *installations;

@end

@implementation FIRCLSInstallIdentifierModel

// This needs to be synthesized so we can set without using the setter in the constructor and
// overridden setters and getters
@synthesize installID = _installID;

- (instancetype)initWithInstallations:(FIRInstallations *)installations {
  self = [super init];
  if (!self) {
    return nil;
  }

  // capture the install ID information
  _installID = [self readInstallationUUID].copy;
  _installations = installations;

  if (!_installID) {
    FIRCLSDebugLog(@"Generating Install ID");
    _installID = [self generateInstallationUUID].copy;

    FIRCLSUserDefaults *defaults = [FIRCLSUserDefaults standardUserDefaults];
    [defaults synchronize];
  }

  return self;
}

- (NSString *)installID {
  @synchronized(self) {
    return _installID;
  }
}

- (void)setInstallID:(NSString *)installID {
  @synchronized(self) {
    _installID = installID;
  }
}

/**
 * Reads installation UUID stored in persistent storage.
 * If the installation UUID is stored in legacy key, migrates it over to the new key.
 */
- (NSString *)readInstallationUUID {
  return [[FIRCLSUserDefaults standardUserDefaults] objectForKey:FIRCLSInstallationUUIDKey];
}

/**
 * Generates a new UUID and saves it in persistent storage.
 * Does not synchronize the user defaults (to allow optimized
 * batching of user default synchronizing)
 */
- (NSString *)generateInstallationUUID {
  NSString *UUID = FIRCLSGenerateUUID();
  FIRCLSUserDefaults *userDefaults = [FIRCLSUserDefaults standardUserDefaults];
  [userDefaults setObject:UUID forKey:FIRCLSInstallationUUIDKey];
  return UUID;
}

#pragma mark Privacy Shield

- (BOOL)regenerateInstallIDIfNeededWithBlock:(void (^)(NSString *fiid, NSString *authToken))block {
  BOOL __block didRotate = false;
  NSString __block *authTokenComplete = @"";
  NSString __block *currentIIDComplete = @"";

  // Installations Completions run async, so wait a reasonable amount of time for it to finish.
  dispatch_group_t workingGroup = dispatch_group_create();

  dispatch_group_enter(workingGroup);
  [self.installations
      authTokenWithCompletion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
        authTokenComplete = tokenResult.authToken;
        dispatch_group_leave(workingGroup);
      }];

  dispatch_group_enter(workingGroup);
  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable currentIID, NSError *_Nullable error) {
        currentIIDComplete = currentIID;
        didRotate = [self rotateCrashlyticsInstallUUIDWithIID:currentIID error:error];

        if (didRotate) {
          FIRCLSInfoLog(@"Rotated Crashlytics Install UUID because Firebase Install ID changed");
        }
        dispatch_group_leave(workingGroup);
      }];

  intptr_t result = dispatch_group_wait(
      workingGroup, dispatch_time(DISPATCH_TIME_NOW, FIRCLSInstallationsWaitTime));

  if (result != 0) {
    FIRCLSErrorLog(@"Crashlytics timed out while checking for Firebase Installation ID");
  }

  // Provide the IID to the callback. For this case we don't care
  // if the FIID is null because it's the best we can do - we just want
  // to send up the same FIID that is sent by other SDKs (eg. the Sessions SDK).
  block(currentIIDComplete, authTokenComplete);
  return didRotate;
}

- (BOOL)rotateCrashlyticsInstallUUIDWithIID:(NSString *_Nullable)currentIID
                                      error:(NSError *_Nullable)error {
  BOOL didRotate = NO;

  FIRCLSUserDefaults *defaults = [FIRCLSUserDefaults standardUserDefaults];

  // Remove the legacy ID
  NSString *adID = [defaults objectForKey:FIRCLSInstallationADIDKey];
  if (adID.length != 0) {
    [defaults removeObjectForKey:FIRCLSInstallationADIDKey];
    [defaults synchronize];
  }

  if (error != nil) {
    FIRCLSErrorLog(@"Failed to get Firebase Instance ID: %@", error);
    return didRotate;
  }

  if (currentIID.length == 0) {
    FIRCLSErrorLog(@"Firebase Instance ID was empty when checked for changes");
    return didRotate;
  }

  NSString *currentIIDHash =
      FIRCLS256HashNSData([currentIID dataUsingEncoding:NSUTF8StringEncoding]);
  NSString *lastIIDHash = [defaults objectForKey:FIRCLSInstallationIIDHashKey];

  // If the IDs are the same, we never regenerate
  if ([lastIIDHash isEqualToString:currentIIDHash]) {
    return didRotate;
  }

  // If we had an FIID saved, we know it's not an upgrade scenario, so we can regenerate
  if (lastIIDHash.length != 0) {
    FIRCLSDebugLog(@"Regenerating Install ID");
    self.installID = [self generateInstallationUUID].copy;
    didRotate = YES;
  }

  // Write the new FIID to UserDefaults
  [defaults setObject:currentIIDHash forKey:FIRCLSInstallationIIDHashKey];
  [defaults synchronize];

  return didRotate;
}

@end
