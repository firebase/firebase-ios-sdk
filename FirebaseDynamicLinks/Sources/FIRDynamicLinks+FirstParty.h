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

#import "FirebaseDynamicLinks/Sources/Public/FirebaseDynamicLinks/FIRDynamicLinks.h"

#import "FirebaseDynamicLinks/Sources/FIRDynamicLink+Private.h"

@class UIViewController;

NS_ASSUME_NONNULL_BEGIN

@interface FIRDynamicLinks (FirstParty)

/**
 * @method setUpWithLaunchOptions::apiKey:clientID:urlScheme:userDefaults:
 * @abstract Set up Dynamic Links.
 * @param launchOptions launchOptions from |application:didFinishLaunchingWithOptions:|. If nil, the
 *     deep link may appear twice on iOS 9 if a user clicks on a link before opening the app.
 * @param apiKey API key for API access.
 * @param clientID client ID for API access.
 * @param urlScheme A custom url scheme used by the application. If nil, bundle id will be used.
 * @param userDefaults The defaults from a user’s defaults database. If nil, standard
 *     NSUserDefaults will be used.
 * @return whether the Dynamic Links was set up successfully.
 */
- (BOOL)setUpWithLaunchOptions:(nullable NSDictionary *)launchOptions
                        apiKey:(NSString *)apiKey
                      clientID:(NSString *)clientID
                     urlScheme:(nullable NSString *)urlScheme
                  userDefaults:(nullable NSUserDefaults *)userDefaults;

/**
 * @method checkForPendingDynamicLink
 * @abstract check for a pending Dynamic Link. This method should be called from your
 *     |UIApplicationDelegate|'s |application:didFinishLaunchingWithOptions:|. If a Dynamic Link is
 *     found, you'll receive an URL in |application:openURL:options:| on iOS9 or later, and
 *     |application:openURL:sourceApplication:annotation| on iOS 8 and earlier. From there you could
 *     get a |GINDeepLink| object by calling |dynamicLinkFromCustomSchemeURL:|. If no Dynamic Link
 *     is found, you will receive callback with "dismiss link". For "dismiss link" the
 *     FIRDynamicLink.url property is nil.
 *     For new integrations prefer to use method
 *     retrievePendingDynamicLinkWithRetrievalProcessType:retrievalOptions:delegate: . This method
 *     will be the only way to use FDL in near future.
 */
- (void)checkForPendingDynamicLink;

/**
 @method checkForPendingDynamicLinkUsingExperimentalRetrievalProcess
 @abstract The same as checkForPendingDynamicLink. Will be using experimental retrieval process.
 */
- (void)checkForPendingDynamicLinkUsingExperimentalRetrievalProcess;

/**
 * @method sharedInstance
 * @abstract Method for compatibility with old interface of the GINDurableDeepLinkService
 */
+ (instancetype)
    sharedInstance DEPRECATED_MSG_ATTRIBUTE("Use [FIRDynamicLinks dynamicLinks] instead.");

/**
 * @method checkForPendingDeepLink
 * @abstract Method for compatibility with old interface of the GINDurableDeepLinkService
 */
- (void)checkForPendingDeepLink DEPRECATED_MSG_ATTRIBUTE(
    "Use [FIRDynamicLinks checkForPendingDynamicLink] instead.");

/**
 * @method deepLinkFromCustomSchemeURL:
 * @abstract Method for compatibility with old interface of the GINDurableDeepLinkService
 */
- (nullable FIRDynamicLink *)deepLinkFromCustomSchemeURL:(NSURL *)url
    DEPRECATED_MSG_ATTRIBUTE("Use [FIRDynamicLinks dynamicLinkFromCustomSchemeURL:] instead.");

/**
 * @method deepLinkFromUniversalLinkURL:
 * @abstract Method for compatibility with old interface of the GINDurableDeepLinkService
 */
- (nullable FIRDynamicLink *)deepLinkFromUniversalLinkURL:(NSURL *)url
    DEPRECATED_MSG_ATTRIBUTE("Use [FIRDynamicLinks dynamicLinkFromUniversalLinkURL:] instead.");

/**
 * @method shouldHandleDeepLinkFromCustomSchemeURL:
 * @abstract Method for compatibility with old interface of the GINDurableDeepLinkService
 */
- (BOOL)shouldHandleDeepLinkFromCustomSchemeURL:(NSURL *)url
    DEPRECATED_MSG_ATTRIBUTE("Use [FIRDynamicLinks shouldHandleDynamicLinkFromCustomSchemeURL:]"
                             " instead.");

@end

NS_ASSUME_NONNULL_END
