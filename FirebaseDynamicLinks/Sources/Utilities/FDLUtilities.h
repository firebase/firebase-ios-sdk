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

FOUNDATION_EXPORT NSString *const kFIRDLParameterDeepLinkIdentifier;
FOUNDATION_EXPORT NSString *const kFIRDLParameterLink;
FOUNDATION_EXPORT NSString *const kFIRDLParameterMinimumAppVersion;
FOUNDATION_EXPORT NSString *const kFIRDLParameterSource;
FOUNDATION_EXPORT NSString *const kFIRDLParameterMedium;
FOUNDATION_EXPORT NSString *const kFIRDLParameterCampaign;
FOUNDATION_EXPORT NSString *const kFIRDLParameterMatchType;
FOUNDATION_EXPORT NSString *const kFIRDLParameterInviteId;
FOUNDATION_EXPORT NSString *const kFIRDLParameterWeakMatchEndpoint;
FOUNDATION_EXPORT NSString *const kFIRDLParameterMatchMessage;
FOUNDATION_EXPORT NSString *const kFIRDLParameterRequestIPVersion;

/**
 * After a Dynamic Link URL is opened in Safari, a cookie is dropped on the domain goo.gl. When a
 * specific URL is used, JavaScript checks if there's a cookie and, if it exists, redirects to the
 * custom-scheme URL stored in it. That causes application:openURL:options: to be called in
 * AppDelegate with the custom-scheme URL. This method creates and returns the URL required to check
 * for the presence of the FDL cookie on goo.gl.
 */
NSURL *FIRDLCookieRetrievalURL(NSString *urlScheme, NSString *bundleID);

/**
 * Creates a URL query string from the contents of an NSDictionary. Single-percent-encoded using
 *     allowed query characters.
 */
NSString *FIRDLURLQueryStringFromDictionary(NSDictionary<NSString *, NSString *> *dictionary);

/**
 * @fn FIRDLDictionaryFromQuery
 * @abstract This receives a URL query parameter string and parses it into a dictionary that
 *     represents the query. This method is necessary as |gtm_dictionaryWithHttpArgumentsString:|
 *     removes the pluses with spaces and, as a result, cannot be used without first replacing all
 *     instances of the plus character with '%2B'.
 * @param queryString The query string of a URL.
 * @return returns a dictionary of type <NSString *, NSString *> that represents the query.
 */
NSDictionary *FIRDLDictionaryFromQuery(NSString *queryString);

/**
 * @fn FIRDLDeepLinkURLWithInviteID
 * @abstract A method that takes the given parameters and constructs a url-scheme-based URL that can
 *     be opened within the containing app, so that the correct link handlers are fired. This is
 *     used after Firebase Dynamic Links either has found a pending deep link, or no link was found.
 * @param inviteID The invitation ID associated with the Dynamic Link. Included in App Invite URLs.
 * @param deepLinkString The deep link, if any, found in the response from a server lookup.
 * @param utmSource The UTM source, if any, found in the response from a server lookup.
 * @param utmMedium The UTM medium, if any, found in the response from a server lookup.
 * @param utmCampaign The UTM campaign, if any, found in the response from a server lookup.
 * @param isWeakLink This value provides information is deep link was weak-matched.
 * @param weakMatchEndpoint This value provides information about which endpoint, IPv4 or IPv6, was
 *     used to perform the lookup if weak match is used.
 * @param minAppVersion The minimum app version string, if any, found in the response from a server
 *     lookup. If this value is provided, the app developer can use it to determine whether or not
 *     to handle the deep link, or to encourage their users to perhaps upgrade their app.
 * @param URLScheme Custom URL scheme of the Application.
 */
NSURL *FIRDLDeepLinkURLWithInviteID(NSString *_Nullable inviteID,
                                    NSString *_Nullable deepLinkString,
                                    NSString *_Nullable utmSource,
                                    NSString *_Nullable utmMedium,
                                    NSString *_Nullable utmCampaign,
                                    BOOL isWeakLink,
                                    NSString *_Nullable weakMatchEndpoint,
                                    NSString *_Nullable minAppVersion,
                                    NSString *URLScheme,
                                    NSString *_Nullable matchMessage);

/**
 * @fn FIRDLOSVersionSupported(NSString *systemVersion, NSString *minSupportedVersion)
 * @abstract Determines if the system version is greater than or equal to the minSupportedVersion.
 * @param systemVersion The iOS version to use as the current version in the comparison.
 * @param minSupportedVersion The minimum iOS system version that is supported.
 * @return YES if the system version is greater than or equal to the minimum, othewise, NO.
 */
BOOL FIRDLOSVersionSupported(NSString *_Nullable systemVersion, NSString *minSupportedVersion);

/**
 Returns date of the App installation. Return value may be nil in case of failure.
 */
NSDate *_Nullable FIRDLAppInstallationDate(void);

/**
 Returns current device model name.
 */
NSString *FIRDLDeviceModelName(void);

/**
 Returns current device locale. The method will try to bring locale format to the same format as
 reported by Safari/WebView.
 */
NSString *FIRDLDeviceLocale(void) __deprecated_msg("Use FIRDeviceLocaleRaw instead");

/**
 Returns current device locale as reported by iOS.
 */
NSString *FIRDLDeviceLocaleRaw(void);

/**
 Returns current device timezone.
 */
NSString *FIRDLDeviceTimezone(void);

/**
 Returns is universal link (long FDL link) parsable.
 */
BOOL FIRDLCanParseUniversalLinkURL(NSURL *_Nullable URL);

/**
 Return is link matches FDL short link format.
 */
BOOL FIRDLMatchesShortLinkFormat(NSURL *URL);

/**
 Returns match type string using server side match type string.
 Returned string can be used as customURLScheme URL with parameter kFIRDLParameterMatchType.
 */
NSString *FIRDLMatchTypeStringFromServerString(NSString *_Nullable serverMatchTypeString);

/**
 Add custom domains from the info.plist to the internal allowlist.
 */
void FIRDLAddToAllowListForCustomDomainsArray(NSArray *customDomains);

NS_ASSUME_NONNULL_END
