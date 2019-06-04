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

@class FIRInstallationsStoredAuthToken;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FIRInstallationsStatus) {
  // Represents either an initial status when a FIRInstallationsItem instance was created but not stored to Keychain or an undefined status (e.g. when the status failed to deserialize).
  FIRInstallationStatusUnknown,
  // The Firebase Installation has not yet been registered with FIS.
  FIRInstallationStatusUnregistered,
  // #CreateInstallation request to FIS server-API is in progress.
  FIRInstallationStatusRegistrationInProgress,
  // The Firebase Installation has successfully been registered with FIS.
  FIRInstallationStatusRegistered,
};


@interface FIRInstallationsStoredItem : NSObject <NSSecureCoding>

@property(nonnull) NSString *firebaseInstallationID;
// The `refershToken` is used to authorize the auth token requests.
@property(nullable) NSString *refreshToken;
@property(nullable) FIRInstallationsStoredAuthToken *authToken;
@property FIRInstallationsStatus registrationStatus;

// The version of local storage.
@property NSInteger storageVersion;
@end

NS_ASSUME_NONNULL_END
