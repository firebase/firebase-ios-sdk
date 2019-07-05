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
 * An authorization token handler block.
 * @param tokenResult An instance of @c FIRInstallationsAuthTokenResult in case of success or @c nil
 * otherwise.
 * @param error The error when @c tokenResult==nil or @c nil otherwise.
 */
typedef void (^FIRInstallationsTokenHandler)(
    FIRInstallationsAuthTokenResult *__nullable tokenResult, NSError *__nullable error)
    NS_SWIFT_NAME(InstallationsTokenHandler);

/**
 * The class provides API for Firebase Installations.
 * Each configured @c FIRApp has a corresponding single instance of @c FIRInstallations.
 * An instance of the class provides access to the installation info for the @c FIRApp as well as
 * allows to delete it. A Firebase Installation is unique by @c FIRApp.name and @c
 * FIRApp.options.googleAppID .
 */
NS_SWIFT_NAME(Installations)
@interface FIRInstallations : NSObject

/**
 * Returns a default instance of @c FIRInstallations.
 * @return Returns an instance of @c FIRInstallations for @c[FIRApp defaultApp]. Returns @c nil if
 * the default app is not configured yet.
 */
+ (nullable FIRInstallations *)installations;

/**
 * Returns an instance of @c FIRInstallations for an application.
 * @param application A configured @c FIRApp instance.
 * @return Returns an instance of @c FIRInstallations corresponding to the passed application.
 */
+ (FIRInstallations *)installationsWithApp:(FIRApp *)application NS_SWIFT_NAME(installations(app:));

/**
 * The method creates or retrieves an installation ID. The installation ID is a stable identifier
 * that uniquely identifies the app instance. NOTE: If the application already has an existing
 * FirebaseInstanceID then the InstanceID ideintifier will be used.
 * @param completion A completion handler which is invoked when the operation completes. See @c
 * FIRInstallationsIDHandler for additional details.
 */
- (void)installationIDWithCompletion:(FIRInstallationsIDHandler)completion;

/**
 * Retrives (locally if exists or from the server) a valid authorization token. An existing token
 * may be invalidated or expire, so it is recommended the auth token before each server request. The
 * method does the same as @c-[FIRInstallations authTokenForcingRefresh:completion:] with forcing
 * refresh @c NO.
 * @param completion A completion handler which is invoked when the operation completes. See @c
 * FIRInstallationsTokenHandler for additional details.
 */
- (void)authTokenWithCompletion:(FIRInstallationsTokenHandler)completion;

/**
 * Retrives (locally or from the server depending on @c forceRefresh value) a valid authorization
 * token. An existing token may be invalidated or expire, so it is recommended the auth token before
 * each server request. This method should be used with @c forceRefresh == YES when e.g. a request
 * with the previously fetched auth token failed with "Not Authorized" error.
 * @param forceRefresh If @c YES then the locally chached auth token will be ignored and a new one
 * will be requested from the server. If @c NO, then the locally cached auth token will be returned
 * if exists and has not expired yet.
 * @param completion  A completion handler which is invoked when the operation completes. See @c
 * FIRInstallationsTokenHandler for additional details.
 */
- (void)authTokenForcingRefresh:(BOOL)forceRefresh
                     completion:(FIRInstallationsTokenHandler)completion;

/**
 * Deletes all the installation data including the unique indentifier, auth tokens and
 * all related data on the server side. The network connection is required for the method to
 * succeed. If fails, the existing instalation data remains untouched.
 * @param completion A completion handler which is invoked when the operation completes. @c error ==
 * nil indicates success.
 */
- (void)deleteWithCompletion:(void (^)(NSError *__nullable error))completion;

@end

NS_ASSUME_NONNULL_END
