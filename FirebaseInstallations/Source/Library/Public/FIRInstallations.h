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
#import <FirebaseInstallations/FIRInstallationsAuthTokenResult.h>
#import <Foundation/Foundation.h>

@class FIRApp;

NS_ASSUME_NONNULL_BEGIN

/** A notification with this name is sent each time an installation is created or deleted. */
FOUNDATION_EXPORT const NSNotificationName FIRInstallationIDDidChangeNotification;

/**
 * An installation ID handler block.
 * @param identifier The instalation ID string if exists or @c nil otherwise.
 * @param error The error when @c identifier==nil or @c nil otherwise.
 */
typedef void (^FIRInstallationsIDHandler)(NSString *__nullable identifier,
                                          NSError *__nullable error)
    NS_SWIFT_NAME(InstallationsIDHandler);

/**
 * An authentification token handler block.
 * @param tokenResult An instance of @c FIRInstallationsAuthTokenResult in case of success or @c nil otherwise.
 * @param error The error when @c tokenResult==nil or @c nil otherwise.
 */
typedef void (^FIRInstallationsTokenHandler)(
    FIRInstallationsAuthTokenResult *__nullable tokenResult, NSError *__nullable error)
    NS_SWIFT_NAME(InstallationsTokenHandler);

/**
 * The class provides API for Firebase Installations.
 * Each configured @c FIRApp has a corresponding single instance of @c FIRInstallations.
 * An instance of the class provides access to the installation info for the @c FIRApp as well as allows to delete it.
 * A Firebase Installation is unique by @c FIRApp.name and @c FIRApp.options.googleAppID .
 */
NS_SWIFT_NAME(Installations)
@interface FIRInstallations : NSObject

/**
 * Returns a default instance of @c FIRInstallations.
 * @return Returns an instance of @c FIRInstallations for @c[FIRApp defaultApp]. Returns @c nil if the default app is not configured yet.
 */
+ (nullable FIRInstallations *)installations;

/**
 * Returns an instance of @c FIRInstallations for an application.
 * @param application A configured @c FIRApp instance.
 * @return Returns an instance of @c FIRInstallations corresponding to the passed application.
 */
+ (FIRInstallations *)installationsWithApp:(FIRApp *)application NS_SWIFT_NAME(installations(app:));

/**
 * 
 */
- (void)installationIDWithCompletion:(FIRInstallationsIDHandler)completion;

- (void)authTokenWithCompletion:(FIRInstallationsTokenHandler)completion;

- (void)authTokenForcingRefresh:(BOOL)forceRefresh
                     completion:(FIRInstallationsTokenHandler)completion;

- (void)deleteWithCompletion:(void (^)(NSError *__nullable))completion;

@end

NS_ASSUME_NONNULL_END
