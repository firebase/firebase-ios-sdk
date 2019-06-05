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

// TODO: Add short docs to the API
#import <Foundation/Foundation.h>

@class FBLPromise<ValueType>;
@class FIRInstallationsItem;
@class FIRSecureStorage;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kFIRInstallationsStoreUserDefaultsID;

@interface FIRInstallationsStore : NSObject

- (instancetype)initWithSecureStorage:(FIRSecureStorage *)storage
                          accessGroup:(nullable NSString *)accessGroup;

// TODO: Consider combining appID and appName to something like FIRInstallationsAppID
- (FBLPromise<FIRInstallationsItem *> *)installationForAppID:(NSString *)appID
                                                     appName:(NSString *)appName;
- (FBLPromise<NSNull *> *)saveInstallation:(FIRInstallationsItem *)installationItem;
- (FBLPromise<NSNull *> *)removeInstallationForAppID:(NSString *)appID appName:(NSString *)appName;

@end

NS_ASSUME_NONNULL_END
