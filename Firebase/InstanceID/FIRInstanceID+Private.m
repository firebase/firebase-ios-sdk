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

#import "FIRInstanceID+Private.h"

#import <FirebaseInstallations/FirebaseInstallations.h>

#import <FirebaseInstanceID/FIRInstanceID_Private.h>
#import "FIRInstanceIDAuthService.h"
#import "FIRInstanceIDTokenManager.h"

@class FIRInstallations;

@interface FIRInstanceID ()

@property(nonatomic, readonly, strong) FIRInstanceIDTokenManager *tokenManager;

@end

@implementation FIRInstanceID (Private)

// This method just wraps our pre-configured auth service to make the request.
// This method is only needed by first-party users, like Remote Config.
- (void)fetchCheckinInfoWithHandler:(FIRInstanceIDDeviceCheckinCompletion)handler {
  [self.tokenManager.authService fetchCheckinInfoWithHandler:handler];
}

- (NSString *)appInstanceID:(NSError **)outError {
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  __block NSString *instanceID;
  __block NSError *error;
  [self.installations installationIDWithCompletion:^(NSString *_Nullable identifier,
                                                     NSError *_Nullable installationIDError) {
    instanceID = identifier;
    error = installationIDError;
    dispatch_semaphore_signal(semaphore);
  }];

  dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
  if (error && outError) {
    *outError = error;
  }

  return instanceID;
}

#pragma mark - Firebase Installations Compatibility

/// Presence of this method indicates that this version of IID uses FirebaseInstallations under the
/// hood. It is checked by FirebaseInstallations SDK.
+ (BOOL)usesFIS {
  return YES;
}

@end
