/*
 * Copyright 2017 Google
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

// A class for wrapping the interactions for retrieving client side info to be used in request
// parameter for interacting with Firebase iam servers.

NS_ASSUME_NONNULL_BEGIN
@interface FIRIAMClientInfoFetcher : NSObject
// Fetch the up-to-date Firebase instance id and token data. Since it involves a server interaction,
// completion callback is provided for receiving the result.
- (void)fetchFirebaseIIDDataWithProjectNumber:(NSString *)projectNumber
                               withCompletion:(void (^)(NSString *_Nullable iid,
                                                        NSString *_Nullable token,
                                                        NSError *_Nullable error))completion;

// Following are synchronous methods for fetching data
- (nullable NSString *)getDeviceLanguageCode;
- (nullable NSString *)getAppVersion;
- (nullable NSString *)getOSVersion;
- (nullable NSString *)getOSMajorVersion;
- (nullable NSString *)getTimezone;
- (NSString *)getIAMSDKVersion;
@end
NS_ASSUME_NONNULL_END
