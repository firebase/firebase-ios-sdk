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

#import "FIRDynamicLink.h"
#import "FIRDynamicLinksCommon.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @file FIRDynamicLinks.h
 * @abstract Firebase Dynamic Links
 */

/**
 * @class FIRDynamicLinks
 * @abstract A class that checks for pending Dynamic Links and parses URLs.
 *     This class is available on iOS only.
 */

NS_EXTENSION_UNAVAILABLE_IOS("Firebase Dynamic Links is not supported for iOS extensions.")
API_UNAVAILABLE(macos, tvos, watchos)
NS_SWIFT_NAME(DynamicLinks)
@interface FIRDynamicLinks : NSObject

/**
 * @method dynamicLinks
 * @abstract Shared instance of FIRDynamicLinks.
 * @return Shared instance of FIRDynamicLinks.
 */
+ (instancetype)dynamicLinks NS_SWIFT_NAME(dynamicLinks());

/**
 * @method shouldHandleDynamicLinkFromCustomSchemeURL:
 * @abstract Determine whether FIRDynamicLinks should handle the given URL. This does not
 *     guarantee that |dynamicLinkFromCustomSchemeURL:| will return a non-nil value, but it means
 *     the client should not attempt to handle the URL.
 * @param url Custom scheme URL.
 * @return Whether the URL can be handled by FIRDynamicLinks.
 */
- (BOOL)shouldHandleDynamicLinkFromCustomSchemeURL:(NSURL *)url
    NS_SWIFT_NAME(shouldHandleDynamicLink(fromCustomSchemeURL:));

/**
 * @method dynamicLinkFromCustomSchemeURL:
 * @abstract Get a Dynamic Link from a custom scheme URL. This method parses URLs with a custom
 *     scheme, for instance, "comgoogleapp://google/link?deep_link_id=abc123". It is suggested to
 *     call it inside your |UIApplicationDelegate|'s
 *     |application:openURL:sourceApplication:annotation| and |application:openURL:options:|
 *     methods.
 * @param url Custom scheme URL.
 * @return Dynamic Link object if the URL is valid and has link parameter, otherwise nil.
 */
- (nullable FIRDynamicLink *)dynamicLinkFromCustomSchemeURL:(NSURL *)url
    NS_SWIFT_NAME(dynamicLink(fromCustomSchemeURL:));

/**
 * @method dynamicLinkFromUniversalLinkURL:completion:
 * @abstract Get a Dynamic Link from a universal link URL. This method parses universal link
 *     URLs, for instance,
 *     "https://example.page.link?link=https://www.google.com&ibi=com.google.app&ius=comgoogleapp".
 *     It is suggested to call it inside your |UIApplicationDelegate|'s
 *     |application:continueUserActivity:restorationHandler:| method.
 * @param url Custom scheme URL.
 * @param completion A block that handles the outcome of attempting to get a Dynamic Link from a
 * universal link URL.
 */
- (void)dynamicLinkFromUniversalLinkURL:(NSURL *)url
                             completion:(FIRDynamicLinkUniversalLinkHandler)completion
    NS_SWIFT_NAME(dynamicLink(fromUniversalLink:completion:));

/**
 * @method dynamicLinkFromUniversalLinkURL:
 * @abstract Get a Dynamic Link from a universal link URL. This method parses universal link
 *     URLs, for instance,
 *     "https://example.page.link?link=https://www.google.com&ibi=com.google.app&ius=comgoogleapp".
 *     It is suggested to call it inside your |UIApplicationDelegate|'s
 *     |application:continueUserActivity:restorationHandler:| method.
 * @param url Custom scheme URL.
 * @return Dynamic Link object if the URL is valid and has link parameter, otherwise nil.
 */
- (nullable FIRDynamicLink *)dynamicLinkFromUniversalLinkURL:(NSURL *)url
    NS_SWIFT_NAME(dynamicLink(fromUniversalLink:))
        DEPRECATED_MSG_ATTRIBUTE("Use dynamicLinkFromUniversalLinkURL:completion: instead.");

/**
 * @method handleUniversalLink:completion:
 * @abstract Convenience method to handle a Universal Link whether it is long or short.
 * @param url A Universal Link URL.
 * @param completion A block that handles the outcome of attempting to create a FIRDynamicLink.
 * @return YES if FIRDynamicLinks is handling the link, otherwise, NO.
 */
- (BOOL)handleUniversalLink:(NSURL *)url completion:(FIRDynamicLinkUniversalLinkHandler)completion;

/**
 * @method resolveShortLink:completion:
 * @abstract Retrieves the details of the Dynamic Link that the shortened URL represents.
 * @param url A Short Dynamic Link.
 * @param completion Block to be run upon completion.
 */
- (void)resolveShortLink:(NSURL *)url completion:(FIRDynamicLinkResolverHandler)completion;

/**
 * @method matchesShortLinkFormat:
 * @abstract Determines if a given URL matches the given short Dynamic Link format.
 * @param url A URL.
 * @return YES if the URL is a short Dynamic Link, otherwise, NO.
 */
- (BOOL)matchesShortLinkFormat:(NSURL *)url;

/**
 * @method performDiagnosticsWithCompletion:
 * @abstract Performs basic FDL self diagnostic. Method effect on startup latency is quite small
 *    and no user-visble UI is presented. This method should be used for debugging purposes.
 *    App developers are encouraged to include output, generated by this method, to the support
 *    requests sent to Firebase support.
 * @param completionHandler Handler that will be called when diagnostic completes.
 *     If value of the completionHandler is nil than diagnostic output will be printed to
 *     the standard output.
 *     diagnosticOutput String that includes diagnostic information.
 *     hasErrors Param will have YES value if diagnostic method detected error, NO otherwise.
 */
+ (void)performDiagnosticsWithCompletion:(void (^_Nullable)(NSString *diagnosticOutput,
                                                            BOOL hasErrors))completionHandler;

@end

NS_ASSUME_NONNULL_END
