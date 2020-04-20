// Copyright 2020 Google LLC
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
#import <AppAuth/AppAuth.h>

NS_ASSUME_NONNULL_BEGIN

// Label exceptions from AppDistributionAuthPersistence calls.
FOUNDATION_EXPORT NSString *const kFIRAppDistributionKeychainErrorDomain;

@interface FIRAppDistributionAuthPersistence : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (BOOL)persistAuthState:(OIDAuthState *)authState error:(NSError **_Nullable)error;

+ (BOOL)clearAuthState:(NSError **_Nullable)error;

+ (OIDAuthState *)retrieveAuthState:(NSError **_Nullable)error;

@end

/**
 *  The set of error codes that may be returned from internal calls to persist Tester authentication
 *  to the keychain. These should never be returned to the user.
 *  @enum FIRAppDistributionKeychainError
 */
typedef NS_ENUM(NSUInteger, FIRAppDistributionKeychainError) {
  // Authentication token persistence error
  FIRAppDistributionErrorTokenPersistenceFailure = 0,

  // Authentication token retrieval error
  FIRAppDistributionErrorTokenRetrievalFailure = 1,

  // Authentication token deletion error
  FIRAppDistributionErrorTokenDeletionFailure = 2,
} NS_SWIFT_NAME(AppDistributionKeychainError);

NS_ASSUME_NONNULL_END
