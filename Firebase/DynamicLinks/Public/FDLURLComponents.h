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

// NS_SWIFT_NAME can only translate factory methods before the iOS 9.3 SDK.
// Wrap it in our own macro if it's a non-compatible SDK.
#ifndef FIR_SWIFT_NAME
#ifdef __IPHONE_9_3
#define FIR_SWIFT_NAME(X) NS_SWIFT_NAME(X)
#else
#define FIR_SWIFT_NAME(X)  // Intentionally blank.
#endif                     // #ifdef __IPHONE_9_3
#endif                     // #ifndef FIR_SWIFT_NAME

NS_ASSUME_NONNULL_BEGIN

/**
 * @abstract Enum used to define the desired path length for shortened Dynamic Link URLs.
 */
typedef NS_ENUM(NSInteger, FIRShortDynamicLinkPathLength) {
  /**
   * Uses the server-default for the path length. See https://goo.gl/8yDAqC for more information.
   */
  FIRShortDynamicLinkPathLengthDefault = 0,
  /** Typical short link for non-sensitive links. */
  FIRShortDynamicLinkPathLengthShort,
  /** Short link with an extra long path for great difficulty in guessing. */
  FIRShortDynamicLinkPathLengthUnguessable,
} FIR_SWIFT_NAME(ShortDynamicLinkPathLength);

/**
 * @abstract The definition of the completion block used by URL shortener.
 * @param shortURL Shortened URL.
 * @param warnings Warnings that describe usability or function limitations of the generated
 *     short link. Usually presence of warnings means parameteres format error, parametres value
 *     error or missing parameter.
 * @param error Error if URL can't be shortened.
 */
typedef void (^FIRDynamicLinkShortenerCompletion)(NSURL *_Nullable shortURL,
                                                  NSArray<NSString *> *_Nullable warnings,
                                                  NSError *_Nullable error)
    FIR_SWIFT_NAME(DynamicLinkShortenerCompletion);

/**
 * @class FIRDynamicLinkGoogleAnalyticsParameters
 * @abstract The Dynamic Link analytics parameters.
 */
FIR_SWIFT_NAME(DynamicLinkGoogleAnalyticsParameters)
@interface FIRDynamicLinkGoogleAnalyticsParameters : NSObject

/**
 * @property source
 * @abstract The utm_source analytics parameter.
 */
@property(nonatomic, copy, nullable) NSString *source;
/**
 * @property medium
 * @abstract The utm_medium analytics parameter.
 */
@property(nonatomic, copy, nullable) NSString *medium;
/**
 * @property campaign
 * @abstract The utm_campaign analytics parameter.
 */
@property(nonatomic, copy, nullable) NSString *campaign;
/**
 * @property term
 * @abstract The utm_term analytics parameter.
 */
@property(nonatomic, copy, nullable) NSString *term;
/**
 * @property content
 * @abstract The utm_content analytics parameter.
 */
@property(nonatomic, copy, nullable) NSString *content;

/**
 * @method parametersWithSource:medium:campaign:
 * @abstract The preferred factory method for creating the analytics parameters object. It includes
 *     the commonly-used source, medium, and campaign fields.
 * @param source The utm_source analytics parameter.
 * @param medium The utm_medium analytics parameter.
 * @param campaign The utm_campaign analytics parameter.
 * @return Returns An object to be used with FIRDynamicLinkURLComponents to add analytics parameters
 *     to a generated Dynamic Link URL.
 */
+ (instancetype)parametersWithSource:(NSString *)source
                              medium:(NSString *)medium
                            campaign:(NSString *)campaign
    NS_SWIFT_UNAVAILABLE("Use init(source:medium:campaign:)");

/**
 * @method parameters
 * @abstract A factory method for creating the analytics parameters object.
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to add analytics parameters
 *     to a generated Dynamic Link URL.
 */
+ (instancetype)parameters NS_SWIFT_UNAVAILABLE("Use init()");

/**
 * @method initWithSource:medium:campaign:
 * @abstract The preferred instance method for creating the analytics parameters object. It
 *     includes the commonly-used source, medium, and campaign fields.
 * @param source The utm_source analytics parameter.
 * @param medium The utm_medium analytics parameter.
 * @param campaign The utm_campaign analytics parameter.
 * @return Returns An object to be used with FIRDynamicLinkURLComponents to add analytics parameters
 *     to a generated Dynamic Link URL.
 */
- (instancetype)initWithSource:(NSString *)source
                        medium:(NSString *)medium
                      campaign:(NSString *)campaign;

/**
 * @method init
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to add analytics parameters
 *     to a generated Dynamic Link URL.
 */
- (instancetype)init;

@end

/**
 * @class FIRDynamicLinkIOSParameters
 * @abstract The Dynamic Link iOS parameters.
 */
FIR_SWIFT_NAME(DynamicLinkIOSParameters)
@interface FIRDynamicLinkIOSParameters : NSObject

/**
 * @property bundleID
 * @abstract The bundle ID of the iOS app to use to open the link.
 */
@property(nonatomic, copy, nullable, readonly) NSString *bundleID;

/**
 * @property appStoreID
 * @abstract The appStore ID of the iOS app in AppStore.
 */
@property(nonatomic, copy, nullable) NSString *appStoreID;

/**
 * @property fallbackURL
 * @abstract The link to open when the app isn't installed. Specify this to do something other than
 *     install the app from the App Store when the app isn't installed, such as open the mobile
 *     web version of the content, or display a promotional page for the app.
 */
@property(nonatomic, nullable) NSURL *fallbackURL;
/**
 * @property customScheme
 * @abstract The target app's custom URL scheme, if defined to be something other than the app's
 *     bundle ID
 */
@property(nonatomic, copy, nullable) NSString *customScheme;
/**
 * @property iPadBundleID
 * @abstract The bundle ID of the iOS app to use on iPads to open the link. This is only required if
 *     there are separate iPhone and iPad applications.
 */
@property(nonatomic, copy, nullable) NSString *iPadBundleID;
/**
 * @property iPadFallbackURL
 * @abstract The link to open on iPads when the app isn't installed. Specify this to do something
 *     other than install the app from the App Store when the app isn't installed, such as open the
 *     web version of the content, or display a promotional page for the app.
 */
@property(nonatomic, nullable) NSURL *iPadFallbackURL;

/**
 @property minimumAppVersion
 @abstract The the minimum version of your app that can open the link. If the
 *     installed app is an older version, the user is taken to the AppStore to upgrade the app.
 *     Note: It is app's developer responsibility to open AppStore when received link declares
 *     higher minimumAppVersion than currently installed.
 */
@property(nonatomic, copy, nullable) NSString *minimumAppVersion;

/**
 * @method parametersWithBundleID:
 * @abstract A method for creating the iOS parameters object.
 * @param bundleID The bundle ID of the iOS app to use to open the link.
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to add iOS parameters to a
 *     generated Dynamic Link URL.
 */
+ (instancetype)parametersWithBundleID:(NSString *)bundleID
    NS_SWIFT_UNAVAILABLE("Use initWithBundleID()");

/**
 * @method initWithBundleID:
 * @abstract A method for creating the iOS parameters object.
 * @param bundleID The bundle ID of the iOS app to use to open the link.
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to add iOS parameters to a
 *     generated Dynamic Link URL.
 */
- (instancetype)initWithBundleID:(NSString *)bundleID;

@end

/**
 * @class FIRDynamicLinkItunesConnectAnalyticsParameters
 * @abstract The Dynamic Link iTunes Connect parameters.
 */
FIR_SWIFT_NAME(DynamicLinkItunesConnectAnalyticsParameters)
@interface FIRDynamicLinkItunesConnectAnalyticsParameters : NSObject

/**
 * @property affiliateToken
 * @abstract The iTunes Connect affiliate token.
 */
@property(nonatomic, copy, nullable) NSString *affiliateToken;
/**
 * @property campaignToken
 * @abstract The iTunes Connect campaign token.
 */
@property(nonatomic, copy, nullable) NSString *campaignToken;
/**
 * @property providerToken
 * @abstract The iTunes Connect provider token.
 */
@property(nonatomic, copy, nullable) NSString *providerToken;

/**
 * @method parameters
 * @abstract A method for creating the iTunes Connect parameters object.
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to add iTunes Connect
 *     parameters to a generated Dynamic Link URL.
 */
+ (instancetype)parameters NS_SWIFT_UNAVAILABLE("Use init()");

/**
 * @method init
 * @abstract A method for creating the iTunes Connect parameters object.
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to add iTunes Connect
 *     parameters to a generated Dynamic Link URL.
 */
- (instancetype)init;

@end

/**
 * @class FIRDynamicLinkAndroidParameters
 * @abstract The Dynamic Link Android parameters.
 */
FIR_SWIFT_NAME(DynamicLinkAndroidParameters)
@interface FIRDynamicLinkAndroidParameters : NSObject

/**
 * @property packageName
 * @abstract The Android app's package name.
 */
@property(nonatomic, copy, nullable, readonly) NSString *packageName;

/**
 * @property fallbackURL
 * @abstract The link to open when the app isn't installed. Specify this to do something other than
 *     install the app from the Play Store when the app isn't installed, such as open the mobile web
 *     version of the content, or display a promotional page for the app.
 */
@property(nonatomic, nullable) NSURL *fallbackURL;
/**
 @property minimumVersion
 @abstract The version code of the minimum version of your app that can open the link. If the
 *     installed app is an older version, the user is taken to the Play Store to upgrade the app.
 */
@property(nonatomic) NSInteger minimumVersion;

/**
 * @method parametersWithPackageName:
 * @abstract A method for creating the Android parameters object.
 * @param packageName The Android app's package name.
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to add Android parameters
 *     to a generated Dynamic Link URL.
 */
+ (instancetype)parametersWithPackageName:(NSString *)packageName
    NS_SWIFT_UNAVAILABLE("Use initWithPackageName()");

/**
 * @method initWithPackageName:
 * @abstract A method for creating the Android parameters object.
 * @param packageName The Android app's package name.
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to add Android parameters
 *     to a generated Dynamic Link URL.
 */
- (instancetype)initWithPackageName:(NSString *)packageName;

@end

/**
 * @class FIRDynamicLinkSocialMetaTagParameters
 * @abstract The Dynamic Link Social Meta Tag parameters.
 */
FIR_SWIFT_NAME(DynamicLinkSocialMetaTagParameters)
@interface FIRDynamicLinkSocialMetaTagParameters : NSObject

/**
 * @property title
 * @abstract The title to use when the Dynamic Link is shared in a social post.
 */
@property(nonatomic, copy, nullable) NSString *title;
/**
 * @property descriptionText
 * @abstract The description to use when the Dynamic Link is shared in a social post.
 */
@property(nonatomic, copy, nullable) NSString *descriptionText;
/**
 * @property imageURL
 * @abstract The URL to an image related to this link.
 */
@property(nonatomic, nullable) NSURL *imageURL;

/**
 * @method parameters
 * @abstract A method for creating the Social Meta Tag parameters object.
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to add Social Meta Tag
 *     parameters to a generated Dynamic Link URL.
 */
+ (instancetype)parameters NS_SWIFT_UNAVAILABLE("Use init()");

/**
 * @method init
 * @abstract A method for creating the Social Meta Tag parameters object.
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to add Social Meta Tag
 *     parameters to a generated Dynamic Link URL.
 */
- (instancetype)init;

@end

/**
 * @class FIRDynamicLinkNavigationInfoParameters
 * @abstract Options class for defining navigation behavior of the Dynamic Link.
 */
FIR_SWIFT_NAME(DynamicLinkNavigationInfoParameters)
@interface FIRDynamicLinkNavigationInfoParameters : NSObject

/**
 * @property forcedRedirectEnabled
 * @abstract Property defines should forced non-interactive redirect be used when link is tapped on
 *   mobile device. Default behavior is to disable force redirect and show interstitial page where
 *   user tap will initiate navigation to the App (or AppStore if not installed). Disabled force
 *   redirect normally improves reliability of the click.
 */
@property(nonatomic, getter=isForcedRedirectEnabled) BOOL forcedRedirectEnabled;

/**
 * @method parameters
 * @abstract A method for creating the Navigation Info parameters object.
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to add Navigation Info
 *     parameters to a generated Dynamic Link URL.
 */
+ (instancetype)parameters NS_SWIFT_UNAVAILABLE("Use init()");

/**
 * @method init
 * @abstract A method for creating the Navigation Info parameters object.
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to add Navigation Info
 *     parameters to a generated Dynamic Link URL.
 */
- (instancetype)init;

@end

/**
 * @class FIRDynamicLinkOtherPlatformParameters
 * @abstract Options class for defining other platform(s) parameters of the Dynamic Link.
 *     Other here means not covered by specific parameters (not iOS and not Android).
 */
FIR_SWIFT_NAME(DynamicLinkOtherPlatformParameters)
@interface FIRDynamicLinkOtherPlatformParameters : NSObject

/**
 * @property fallbackUrl
 * @abstract Property defines fallback URL to navigate to when Dynamic Link is clicked on
 *     other platform.
 */
@property(nonatomic, nullable) NSURL *fallbackUrl;

/**
 * @method parameters
 * @abstract A method for creating the Other platform parameters object.
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to add Other Platform
 *     parameters to a generated Dynamic Link URL.
 */
+ (instancetype)parameters NS_SWIFT_UNAVAILABLE("Use init()");

- (instancetype)init;

@end

/**
 * @class FIRDynamicLinkComponentsOptions
 * @abstract Options class for defining how Dynamic Link URLs are generated.
 */
FIR_SWIFT_NAME(DynamicLinkComponentsOptions)
@interface FIRDynamicLinkComponentsOptions : NSObject

/**
 * @property pathLength
 * @abstract Specifies the length of the path component of a short Dynamic Link.
 */
@property(nonatomic) FIRShortDynamicLinkPathLength pathLength;

/**
 * @method options
 * @abstract A method for creating the Dynamic Link components options object.
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to specify options related
 *     to the generation of Dynamic Link URLs.
 */
+ (instancetype)options NS_SWIFT_UNAVAILABLE("Use init()");

/**
 * @method init
 * @abstract A method for creating the Dynamic Link components options object.
 * @return Returns an object to be used with FIRDynamicLinkURLComponents to specify options related
 *     to the generation of Dynamic Link URLs.
 */
- (instancetype)init;

@end

/**
 * @class FIRDynamicLinkComponents
 * @abstract The class used for Dynamic Link URL generation; supports creation of short and long
 *     Dynamic Link URLs. Short URLs will have a domain and a randomized path; long URLs will have a
 *     domain and a query that contains all of the Dynamic Link parameters.
 */
FIR_SWIFT_NAME(DynamicLinkComponents)
@interface FIRDynamicLinkComponents : NSObject

/**
 * @property analyticsParameters
 * @abstract Applies Analytics parameters to a generated Dynamic Link URL.
 */
@property(nonatomic, nullable) FIRDynamicLinkGoogleAnalyticsParameters *analyticsParameters;
/**
 * @property socialMetaTagParameters
 * @abstract Applies Social Meta Tag parameters to a generated Dynamic Link URL.
 */
@property(nonatomic, nullable) FIRDynamicLinkSocialMetaTagParameters *socialMetaTagParameters;
/**
 * @property iOSParameters
 * @abstract Applies iOS parameters to a generated Dynamic Link URL.
 */
@property(nonatomic, nullable) FIRDynamicLinkIOSParameters *iOSParameters;
/**
 * @property iTunesConnectParameters
 * @abstract Applies iTunes Connect parameters to a generated Dynamic Link URL.
 */
@property(nonatomic, nullable)
    FIRDynamicLinkItunesConnectAnalyticsParameters *iTunesConnectParameters;
/**
 * @property androidParameters
 * @abstract Applies Android parameters to a generated Dynamic Link URL.
 */
@property(nonatomic, nullable) FIRDynamicLinkAndroidParameters *androidParameters;
/**
 * @property navigationInfoParameters
 * @abstract Applies Navigation Info parameters to a generated Dynamic Link URL.
 */
@property(nonatomic, nullable) FIRDynamicLinkNavigationInfoParameters *navigationInfoParameters;
/**
 * @property otherPlatformParameters
 * @abstract Applies Other platform parameters to a generated Dynamic Link URL.
 */
@property(nonatomic, nullable) FIRDynamicLinkOtherPlatformParameters *otherPlatformParameters;
/**
 * @property options
 * @abstract Defines behavior for generating Dynamic Link URLs.
 */
@property(nonatomic, nullable) FIRDynamicLinkComponentsOptions *options;

/**
 * @property link
 * @abstract The link the target app will open. You can specify any URL the app can handle, such as
 *     a link to the app's content, or a URL that initiates some app-specific logic such as
 *     crediting the user with a coupon, or displaying a specific welcome screen. This link must be
 *     a well-formatted URL, be properly URL-encoded, and use the HTTP or HTTPS scheme.
 */
@property(nonatomic) NSURL *link;
/**
 * @property domain
 * @abstract The Firebase project's Dynamic Links domain. You can find this value in the Dynamic
 *     Links section of the Firebase console.
 *     https://console.firebase.google.com/
 */
@property(nonatomic, nullable, copy) NSString *domain;

/**
 * @property url
 * @abstract A generated long Dynamic Link URL.
 */
@property(nonatomic, nullable, readonly) NSURL *url;

/**
 * @method componentsWithLink:domainURIPrefix:
 * @abstract Generates a Dynamic Link URL components object with the minimum necessary parameters
 *     set to generate a fully-functional Dynamic Link.
 * @param link Deep link to be stored in created Dynamic link. This link also called "payload" of
 *     the Dynamic link.
 * @param domainURIPrefix Domain URI Prefix of your App. This value must be your assigned
 * domain from the Firebase console. (e.g. https://xyz.page.link)  The domain URI prefix must
 * start with a valid HTTPS scheme (https://).
 * @return Returns an instance of FIRDynamicLinkComponents if the parameters succeed validation,
 * else returns nil.
 */
+ (nullable instancetype)componentsWithLink:(NSURL *)link
                            domainURIPrefix:(NSString *)domainURIPrefix
    NS_SWIFT_UNAVAILABLE("Use init(link:domainURIPrefix:)");

/**
 * @method initWithLink:domainURIPrefix:
 * @abstract Generates a Dynamic Link URL components object with the minimum necessary parameters
 *     set to generate a fully-functional Dynamic Link.
 * @param link Deep link to be stored in created Dynamic link. This link also called "payload" of
 *     the Dynamic link.
 * @param domainURIPrefix Domain URI Prefix of your App. This value must be your assigned
 * domain from the Firebase console. (e.g. https://xyz.page.link)  The domain URI prefix must
 * start with a valid HTTPS scheme (https://).
 * @return Returns an instance of FIRDynamicLinkComponents if the parameters succeed validation,
 * else returns nil.
 */
- (nullable instancetype)initWithLink:(NSURL *)link domainURIPrefix:(NSString *)domainURIPrefix;

/**
 * @method shortenURL:options:completion:
 * @abstract Shortens a Dynamic Link URL. This method may be used for shortening a custom URL that
 *     was not generated using FIRDynamicLinkComponents.
 * @param url A properly-formatted long Dynamic Link URL.
 * @param completion A block to be executed upon completion of the shortening attempt. It is
 *     guaranteed to be executed once and on the main thread.
 */
+ (void)shortenURL:(NSURL *)url
           options:(FIRDynamicLinkComponentsOptions *_Nullable)options
        completion:(FIRDynamicLinkShortenerCompletion)completion;

/**
 * @method shortenWithCompletion:
 * @abstract Generates a short Dynamic Link URL using all set parameters.
 * @param completion A block to be executed upon completion of the shortening attempt. It is
 *     guaranteed to be executed once and on the main thread.
 */
- (void)shortenWithCompletion:(FIRDynamicLinkShortenerCompletion)completion;

@end

NS_ASSUME_NONNULL_END
