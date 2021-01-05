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

#import "Firebase/InstanceID/Private/FIRInstanceID+Private.h"

#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"

#import "Firebase/InstanceID/FIRInstanceIDAuthService.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenManager.h"
#import "Firebase/InstanceID/Private/FIRInstanceID_Private.h"

@class FIRInstallations;

@interface FIRInstanceID ()

@property(nonatomic, readonly, strong) FIRInstanceIDTokenManager *tokenManager;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
@implementation FIRInstanceID (Private)
#pragma clang diagnostic pop

// This method just wraps our pre-configured auth service to make the request.
// This method is only needed by first-party users, like Remote Config.
- (void)fetchCheckinInfoWithHandler:(FIRInstanceIDDeviceCheckinCompletion)handler {
  [self.tokenManager.authService fetchCheckinInfoWithHandler:handler];
}

#pragma mark - Firebase Installations Compatibility

/// Presence of this method indicates that this version of IID uses FirebaseInstallations under the
/// hood. It is checked by FirebaseInstallations SDK.
+ (BOOL)usesFIS {
  return YES;
}

@end
