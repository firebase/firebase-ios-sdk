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

// TODO: Replace by import.
@class FIRAuthTokenResult;

@class FIRApp;

NS_ASSUME_NONNULL_BEGIN

typedef void (^FIRInstallationsIDHandler)(NSString *__nullable identifier,
                                          NSError *__nullable error)
    NS_SWIFT_NAME(InstallationsIDHandler);

typedef void (^FIRInstallationsTokenHandler)(FIRAuthTokenResult *__nullable tokenResult,
                                             NSError *__nullable error)
    NS_SWIFT_NAME(InstallationsTokenHandler);

typedef void (^FIRInstallationsDeleteHandler)(NSError *__nullable error)
    NS_SWIFT_NAME(InstallationsDeleteHandler);

@interface FIRInstallations : NSObject

+ (FIRInstallations *)installationsWithApp:(FIRApp *)application;

- (void)installationIDWithCompletion:(FIRInstallationsIDHandler)handler;

- (void)authTokenWithCompletion:(FIRInstallationsTokenHandler)handler;

- (void)deleteWithCompletion:(FIRInstallationsDeleteHandler)handler;

@end

NS_ASSUME_NONNULL_END
