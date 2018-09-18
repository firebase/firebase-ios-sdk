/*
 * Copyright 2018 Google
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

/**
 This is a temporary solution so that apps can use AppInvite and DDL.
 This is only for use with iOS 9+ and will not function for lower versions.
 */
@interface GINDurableDeepLinkServiceReceiving : NSObject

/**
 * @method checkForPendingDeepLinkWithUserDefaults:customScheme:
 * @abstract Checks for a pending Durable Link. Works with iOS 9+ only!
 * @param userDefaults The user defaults object used for the app.
 * @param customScheme The custom scheme of the application
              ex. comgooglemaps for Google Maps
 */
- (void)checkForPendingDeepLinkWithUserDefaults:(NSUserDefaults *)userDefaults
                                   customScheme:(nullable NSString *)customScheme
                               bundleIdentifier:(nullable NSString *)bundleIdentifier;

@end

NS_ASSUME_NONNULL_END
