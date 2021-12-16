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

#import <Foundation/Foundation.h>

#import <FirebaseFunctions/FIRFunctions.h>

NS_ASSUME_NONNULL_BEGIN

/// A functions object with fake tokens.
NS_SWIFT_NAME(FunctionsFake)
@interface FIRFunctionsFake : FIRFunctions

/**
 * Internal initializer for testing a Cloud Functions client with fakes.
 * @param projectID The project ID for the Firebase project.
 * @param region The region for the http trigger, such as "us-central1".
 * @param customDomain A custom domain for the http trigger, such as "https://mydomain.com".
 * @param token A token to use for validation (optional).
 */
- (instancetype)initWithProjectID:(NSString *)projectID
                           region:(NSString *)region
                     customDomain:(nullable NSString *)customDomain
                        withToken:(nullable NSString *)token;
@end

NS_ASSUME_NONNULL_END
