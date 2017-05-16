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

NS_ASSUME_NONNULL_BEGIN

/** @class FIRActionCodeSettings
    @brief Used to set and retrieve settings related to the handling action codes.
 */
@interface FIRActionCodeSettings : NSObject

/** @property URL
    @brief This URL represents the state/Continue URL in the form of a universal link.
    @remarks This URL can should be contructed as a universal link that would either directly open
        the app where the action code would be handled or continue to the app after the action code
        handled by Firebase.
 */
@property(nonatomic, copy, nullable) NSURL *URL;

/** @property handleCodeInApp
    @brief Indicates whether or not the action code link will open the app directly or after being
        redirected from a Firebase owned web widget.
 */
@property(assign, nonatomic) BOOL handleCodeInApp;

/** @property iOSBundleID
    @brief The iOS bundle ID, if available.
 */
@property(copy, nonatomic, readonly, nullable) NSString *iOSBundleID;

/** @property iOSAppStoreID
    @brief The iOS app store identifier, if available.
 */
@property(nonatomic, copy, readonly, nullable) NSString *iOSAppStoreID;

/** @property androidPackageName
    @brief The Android package name, if available.
 */
@property(nonatomic, copy, readonly, nullable) NSString *androidPackageName;

/** @property androidMinimumVersion
    @brief The minimum Android version supported, if available.
 */
@property(nonatomic, copy, readonly, nullable) NSString *androidMinimumVersion;

/** @property androidInstallIfNotAvailable
    @brief Indicates whether or not the Android app should be installed if not already available.
 */
@property(nonatomic, assign, readonly) BOOL androidInstallIfNotAvailable;

/** @fn setIOSBundleID:appStoreID
    @brief Sets the iOS bundle Id and appStoreID.
    @param iOSBundleID The iOS bundle ID.
    @param appStoreID The app's AppStore ID.
    @remarks If the app is not already installed on an iOS device and an appStoreId is provided, the
        app store page of the app will be opened. If no app store ID is provided, the web app link
        will be used instead.
 */
- (void)setIOSBundleID:(NSString *)iOSBundleID appStoreID:(nullable NSString *)appStoreID;

/** @fn setAndroidPackageName:installIfNotAvailable:minimumVersion:
    @brief Sets the Android package name, the flag to indicate whether or not to install the app and
        the minimum Android version supported.
    @param androidPackageName The Android package name.
    @param installIfNotAvailable Indicates whether or not the app should be installed if not
        available.
    @param minimumVersion The minimum version of Android supported.
    @remarks If installIfNotAvailable is set to YES and the link is opened on an android device, it
        will try to install the app if not already available. Otherwise the web URL is used.
 */
- (void)setAndroidPackageName:(NSString *)androidPackageName
        installIfNotAvailable:(BOOL)installIfNotAvailable
               minimumVersion:(nullable NSString *)minimumVersion;

@end

NS_ASSUME_NONNULL_END
