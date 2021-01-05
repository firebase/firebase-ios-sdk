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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>

#import "FirebaseDynamicLinks/Sources/FDLURLComponents/FDLURLComponents+Private.h"
#import "FirebaseDynamicLinks/Sources/FDLURLComponents/FIRDynamicLinkComponentsKeyProvider.h"
#import "FirebaseDynamicLinks/Sources/Public/FirebaseDynamicLinks/FDLURLComponents.h"

#import "FirebaseDynamicLinks/Sources/Logging/FDLLogging.h"
#import "FirebaseDynamicLinks/Sources/Utilities/FDLUtilities.h"

// Label exceptions from FDL.
NSString *const kFirebaseDurableDeepLinkErrorDomain = @"com.firebase.durabledeeplink";

/// The exact behavior of dict[key] = value is unclear when value is nil. This function safely adds
/// the key-value pair to the dictionary, even when value is nil.
/// This function will treat empty string in the same way as nil.
NS_INLINE void FDLSafelyAddKeyValuePairToDictionary(NSString *key,
                                                    NSString *stringValue,
                                                    NSMutableDictionary *dictionary) {
  if (stringValue != nil && stringValue.length > 0) {
    dictionary[key] = stringValue;
  } else {
    [dictionary removeObjectForKey:key];
  }
}

@implementation FIRDynamicLinkGoogleAnalyticsParameters {
  NSMutableDictionary<NSString *, NSString *> *_dictionary;
}

static NSString *const kFDLUTMSourceKey = @"utm_source";
static NSString *const kFDLUTMMediumKey = @"utm_medium";
static NSString *const kFDLUTMCampaignKey = @"utm_campaign";
static NSString *const kFDLUTMTermKey = @"utm_term";
static NSString *const kFDLUTMContentKey = @"utm_content";

+ (instancetype)parameters {
  return [[self alloc] init];
}

+ (instancetype)parametersWithSource:(NSString *)source
                              medium:(NSString *)medium
                            campaign:(NSString *)campaign {
  return [[self alloc] initWithSource:source medium:medium campaign:campaign];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _dictionary = [NSMutableDictionary dictionary];
  }
  return self;
}

- (instancetype)initWithSource:(NSString *)source
                        medium:(NSString *)medium
                      campaign:(NSString *)campaign {
  self = [self init];
  if (self) {
    FDLSafelyAddKeyValuePairToDictionary(kFDLUTMSourceKey, [source copy], _dictionary);
    FDLSafelyAddKeyValuePairToDictionary(kFDLUTMMediumKey, [medium copy], _dictionary);
    FDLSafelyAddKeyValuePairToDictionary(kFDLUTMCampaignKey, [campaign copy], _dictionary);
  }
  return self;
}

- (void)setSource:(NSString *)source {
  FDLSafelyAddKeyValuePairToDictionary(kFDLUTMSourceKey, [source copy], _dictionary);
}

- (NSString *)source {
  return _dictionary[kFDLUTMSourceKey];
}

- (void)setMedium:(NSString *)medium {
  FDLSafelyAddKeyValuePairToDictionary(kFDLUTMMediumKey, [medium copy], _dictionary);
}

- (NSString *)medium {
  return _dictionary[kFDLUTMMediumKey];
}

- (void)setCampaign:(NSString *)campaign {
  FDLSafelyAddKeyValuePairToDictionary(kFDLUTMCampaignKey, [campaign copy], _dictionary);
}

- (NSString *)campaign {
  return _dictionary[kFDLUTMCampaignKey];
}

- (void)setTerm:(NSString *)term {
  FDLSafelyAddKeyValuePairToDictionary(kFDLUTMTermKey, [term copy], _dictionary);
}

- (NSString *)term {
  return _dictionary[kFDLUTMTermKey];
}

- (void)setContent:(NSString *)content {
  FDLSafelyAddKeyValuePairToDictionary(kFDLUTMContentKey, [content copy], _dictionary);
}

- (NSString *)content {
  return _dictionary[kFDLUTMContentKey];
}

- (NSDictionary<NSString *, NSString *> *)dictionaryRepresentation {
  return [_dictionary copy];
}

@end

@implementation FIRDynamicLinkIOSParameters {
  NSMutableDictionary<NSString *, NSString *> *_dictionary;
}

static NSString *const kFDLIOSBundleIdentifierKey = @"ibi";
static NSString *const kFDLIOSAppStoreIdentifierKey = @"isi";
static NSString *const kFDLIOSFallbackURLKey = @"ifl";
static NSString *const kFDLIOSCustomURLSchemeKey = @"ius";
static NSString *const kFDLIOSMinimumVersionKey = @"imv";
static NSString *const kFDLIOSIPadBundleIdentifierKey = @"ipbi";
static NSString *const kFDLIOSIPadFallbackURLKey = @"ipfl";

+ (instancetype)parametersWithBundleID:(NSString *)bundleID {
  return [[self alloc] initWithBundleID:bundleID];
}

- (instancetype)initWithBundleID:(NSString *)bundleID {
  self = [super init];
  if (self) {
    _dictionary = [NSMutableDictionary dictionary];
    FDLSafelyAddKeyValuePairToDictionary(kFDLIOSBundleIdentifierKey, [bundleID copy], _dictionary);
  }
  return self;
}

- (NSString *)bundleID {
  return _dictionary[kFDLIOSBundleIdentifierKey];
}

- (void)setAppStoreID:(NSString *)appStoreID {
  FDLSafelyAddKeyValuePairToDictionary(kFDLIOSAppStoreIdentifierKey, [appStoreID copy],
                                       _dictionary);
}

- (NSString *)appStoreID {
  return _dictionary[kFDLIOSAppStoreIdentifierKey];
}

- (void)setFallbackURL:(NSURL *)fallbackURL {
  FDLSafelyAddKeyValuePairToDictionary(kFDLIOSFallbackURLKey, fallbackURL.absoluteString,
                                       _dictionary);
}

- (NSURL *)fallbackURL {
  NSString *fallbackURLString = _dictionary[kFDLIOSFallbackURLKey];
  return fallbackURLString != nil ? [NSURL URLWithString:fallbackURLString] : nil;
}

- (void)setCustomScheme:(NSString *)customScheme {
  FDLSafelyAddKeyValuePairToDictionary(kFDLIOSCustomURLSchemeKey, [customScheme copy], _dictionary);
}

- (NSString *)customScheme {
  return _dictionary[kFDLIOSCustomURLSchemeKey];
}

- (void)setMinimumAppVersion:(NSString *)minimumAppVersion {
  FDLSafelyAddKeyValuePairToDictionary(kFDLIOSMinimumVersionKey, [minimumAppVersion copy],
                                       _dictionary);
}

- (NSString *)minimumAppVersion {
  return _dictionary[kFDLIOSMinimumVersionKey];
}

- (void)setIPadBundleID:(NSString *)iPadBundleID {
  FDLSafelyAddKeyValuePairToDictionary(kFDLIOSIPadBundleIdentifierKey, [iPadBundleID copy],
                                       _dictionary);
}

- (NSString *)iPadBundleID {
  return _dictionary[kFDLIOSIPadBundleIdentifierKey];
}

- (void)setIPadFallbackURL:(NSURL *)iPadFallbackURL {
  FDLSafelyAddKeyValuePairToDictionary(kFDLIOSIPadFallbackURLKey, iPadFallbackURL.absoluteString,
                                       _dictionary);
}

- (NSURL *)iPadFallbackURL {
  NSString *fallbackURLString = _dictionary[kFDLIOSIPadFallbackURLKey];
  return fallbackURLString != nil ? [NSURL URLWithString:fallbackURLString] : nil;
}

- (NSDictionary<NSString *, NSString *> *)dictionaryRepresentation {
  return [_dictionary copy];
}

@end

@implementation FIRDynamicLinkItunesConnectAnalyticsParameters {
  NSMutableDictionary<NSString *, NSString *> *_dictionary;
}

static NSString *const kFDLITunesConnectAffiliateTokeyKey = @"at";
static NSString *const kFDLITunesConnectCampaignTokenKey = @"ct";
static NSString *const kFDLITunesConnectProviderTokenKey = @"pt";

+ (instancetype)parameters {
  return [[self alloc] init];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _dictionary = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)setAffiliateToken:(NSString *)affiliateToken {
  FDLSafelyAddKeyValuePairToDictionary(kFDLITunesConnectAffiliateTokeyKey, [affiliateToken copy],
                                       _dictionary);
}

- (NSString *)affiliateToken {
  return _dictionary[kFDLITunesConnectAffiliateTokeyKey];
}

- (void)setCampaignToken:(NSString *)campaignToken {
  FDLSafelyAddKeyValuePairToDictionary(kFDLITunesConnectCampaignTokenKey, [campaignToken copy],
                                       _dictionary);
}

- (NSString *)campaignToken {
  return _dictionary[kFDLITunesConnectCampaignTokenKey];
}

- (void)setProviderToken:(NSString *)providerToken {
  FDLSafelyAddKeyValuePairToDictionary(kFDLITunesConnectProviderTokenKey, [providerToken copy],
                                       _dictionary);
}

- (NSString *)providerToken {
  return _dictionary[kFDLITunesConnectProviderTokenKey];
}

- (NSDictionary<NSString *, NSString *> *)dictionaryRepresentation {
  return [_dictionary copy];
}

@end

@implementation FIRDynamicLinkAndroidParameters {
  NSMutableDictionary<NSString *, NSString *> *_dictionary;
}

static NSString *const kFDLAndroidMinimumVersionKey = @"amv";
static NSString *const kFDLAndroidFallbackURLKey = @"afl";
static NSString *const kFDLAndroidPackageNameKey = @"apn";

+ (instancetype)parametersWithPackageName:(NSString *)packageName {
  return [[self alloc] initWithPackageName:packageName];
}

- (instancetype)initWithPackageName:(NSString *)packageName {
  self = [super init];
  if (self) {
    _dictionary = [NSMutableDictionary dictionary];
    FDLSafelyAddKeyValuePairToDictionary(kFDLAndroidPackageNameKey, packageName, _dictionary);
  }
  return self;
}

- (NSString *)packageName {
  return _dictionary[kFDLAndroidPackageNameKey];
}

- (void)setMinimumVersion:(NSInteger)minimumVersion {
  _dictionary[kFDLAndroidMinimumVersionKey] = @(minimumVersion).stringValue;
}

- (NSInteger)minimumVersion {
  return _dictionary[kFDLAndroidMinimumVersionKey].integerValue;
}

- (void)setFallbackURL:(NSURL *)fallbackURL {
  FDLSafelyAddKeyValuePairToDictionary(kFDLAndroidFallbackURLKey, fallbackURL.absoluteString,
                                       _dictionary);
}

- (NSURL *)fallbackURL {
  NSString *fallbackURLString = _dictionary[kFDLAndroidFallbackURLKey];
  return fallbackURLString != nil ? [NSURL URLWithString:fallbackURLString] : nil;
}

- (NSDictionary<NSString *, NSString *> *)dictionaryRepresentation {
  return [_dictionary copy];
}

@end

@implementation FIRDynamicLinkSocialMetaTagParameters {
  NSMutableDictionary<NSString *, NSString *> *_dictionary;
}

static NSString *const kFDLSocialTitleKey = @"st";
static NSString *const kFDLSocialDescriptionKey = @"sd";
static NSString *const kFDLSocialImageURLKey = @"si";

+ (instancetype)parameters {
  return [[self alloc] init];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _dictionary = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)setTitle:(NSString *)title {
  FDLSafelyAddKeyValuePairToDictionary(kFDLSocialTitleKey, [title copy], _dictionary);
}

- (NSString *)title {
  return _dictionary[kFDLSocialTitleKey];
}

- (void)setDescriptionText:(NSString *)descriptionText {
  FDLSafelyAddKeyValuePairToDictionary(kFDLSocialDescriptionKey, [descriptionText copy],
                                       _dictionary);
}

- (NSString *)descriptionText {
  return _dictionary[kFDLSocialDescriptionKey];
}

- (void)setImageURL:(NSURL *)imageURL {
  FDLSafelyAddKeyValuePairToDictionary(kFDLSocialImageURLKey, imageURL.absoluteString, _dictionary);
}

- (NSURL *)imageURL {
  NSString *imageURLString = _dictionary[kFDLSocialImageURLKey];
  return imageURLString != nil ? [NSURL URLWithString:imageURLString] : nil;
}

- (NSDictionary<NSString *, NSString *> *)dictionaryRepresentation {
  return [_dictionary copy];
}

@end

@implementation FIRDynamicLinkNavigationInfoParameters {
  NSMutableDictionary<NSString *, NSString *> *_dictionary;
}

static NSString *const kFDLNavigationInfoForceRedirectKey = @"efr";

+ (instancetype)parameters {
  return [[self alloc] init];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _dictionary = [NSMutableDictionary dictionary];
  }
  return self;
}

- (BOOL)isForcedRedirectEnabled {
  return [_dictionary[kFDLNavigationInfoForceRedirectKey] boolValue];
}

- (void)setForcedRedirectEnabled:(BOOL)forcedRedirectEnabled {
  FDLSafelyAddKeyValuePairToDictionary(kFDLNavigationInfoForceRedirectKey,
                                       forcedRedirectEnabled ? @"1" : @"0", _dictionary);
}

- (NSDictionary<NSString *, NSString *> *)dictionaryRepresentation {
  return [_dictionary copy];
}

@end

@implementation FIRDynamicLinkOtherPlatformParameters {
  NSMutableDictionary<NSString *, NSString *> *_dictionary;
}

static NSString *const kFDLOtherPlatformParametersFallbackURLKey = @"ofl";

+ (instancetype)parameters {
  return [[self alloc] init];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _dictionary = [NSMutableDictionary dictionary];
  }
  return self;
}

- (NSURL *)fallbackUrl {
  NSString *fallbackURLString = _dictionary[kFDLOtherPlatformParametersFallbackURLKey];
  return fallbackURLString != nil ? [NSURL URLWithString:fallbackURLString] : nil;
}

- (void)setFallbackUrl:(NSURL *)fallbackUrl {
  FDLSafelyAddKeyValuePairToDictionary(kFDLOtherPlatformParametersFallbackURLKey,
                                       fallbackUrl.absoluteString, _dictionary);
}

- (NSDictionary<NSString *, NSString *> *)dictionaryRepresentation {
  return [_dictionary copy];
}

@end

@implementation FIRDynamicLinkComponentsOptions

+ (instancetype)options {
  return [[self alloc] init];
}

// This is implemented to silence the 'not implemented' warning.
- (instancetype)init {
  return [super init];
}

@end

@implementation FIRDynamicLinkComponents

#pragma mark Deprecated Initializers.
+ (instancetype)componentsWithLink:(NSURL *)link domain:(NSString *)domain {
  return [[self alloc] initWithLink:link domain:domain];
}

- (instancetype)initWithLink:(NSURL *)link domain:(NSString *)domain {
  NSURL *domainURL = [NSURL URLWithString:domain];
  if (domainURL.scheme) {
    FDLLog(FDLLogLevelWarning, FDLLogIdentifierSetupWarnHTTPSScheme,
           @"You have supplied a domain with a scheme. Please enter a domain name without the "
           @"scheme.");
  }
  NSString *domainURIPrefix = [NSString stringWithFormat:@"https://%@", domain];
  self = [super init];
  if (self) {
    _link = link;
    _domain = domainURIPrefix;
  }
  return self;
}

#pragma mark Initializers.
+ (instancetype)componentsWithLink:(NSURL *)link domainURIPrefix:(NSString *)domainURIPrefix {
  return [[self alloc] initWithLink:link domainURIPrefix:domainURIPrefix];
}

- (instancetype)initWithLink:(NSURL *)link domainURIPrefix:(NSString *)domainURIPrefix {
  self = [super init];
  if (self) {
    _link = link;
    /// Must be a URL that conforms to RFC 2396.
    NSURL *domainURIPrefixURL = [NSURL URLWithString:domainURIPrefix];
    if (!domainURIPrefixURL) {
      FDLLog(FDLLogLevelError, FDLLogIdentifierSetupInvalidDomainURIPrefix,
             @"Invalid domainURIPrefix. Please input a valid URL.");
      return nil;
    }
    if (![[domainURIPrefixURL.scheme lowercaseString] isEqualToString:@"https"]) {
      FDLLog(FDLLogLevelError, FDLLogIdentifierSetupInvalidDomainURIPrefixScheme,
             @"Invalid domainURIPrefix scheme. Scheme needs to be https");
      return nil;
    }
    _domain = [domainURIPrefix copy];
  }
  return self;
}

+ (void)shortenURL:(NSURL *)url
           options:(FIRDynamicLinkComponentsOptions *)options
        completion:(FIRDynamicLinkShortenerCompletion)completion {
  if (![FIRDynamicLinkComponentsKeyProvider APIKey]) {
    NSError *error = [NSError
        errorWithDomain:kFirebaseDurableDeepLinkErrorDomain
                   code:0
               userInfo:@{
                 NSLocalizedFailureReasonErrorKey : NSLocalizedString(
                     @"API key is missing.", @"Error reason message when API key is missing"),
               }];
    completion(nil, nil, error);
    return;
  }
  NSURLRequest *request = [self shorteningRequestForLongURL:url options:options];
  if (!request) {
    NSError *error = [NSError errorWithDomain:kFirebaseDurableDeepLinkErrorDomain
                                         code:0
                                     userInfo:nil];
    completion(nil, nil, error);
    return;
  }
  [self sendHTTPRequest:request
             completion:^(NSData *_Nullable data, NSError *_Nullable error) {
               NSURL *shortURL;
               NSArray *warnings;
               if (data != nil && error == nil) {
                 NSError *deserializationError;
                 id JSONObject = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:0
                                                                   error:&deserializationError];

                 if ([JSONObject isKindOfClass:[NSDictionary class]]) {
                   if ([JSONObject[@"shortLink"] isKindOfClass:[NSString class]]) {
                     shortURL = [NSURL URLWithString:JSONObject[@"shortLink"]];
                   } else {
                     if ([JSONObject[@"error"] isKindOfClass:[NSDictionary class]]) {
                       NSMutableDictionary *errorUserInfo = [[NSMutableDictionary alloc] init];

                       NSDictionary *errorDictionary = JSONObject[@"error"];
                       if ([errorDictionary[@"message"] isKindOfClass:[NSString class]]) {
                         errorUserInfo[NSLocalizedFailureReasonErrorKey] =
                             errorDictionary[@"message"];
                       }
                       if ([errorDictionary[@"status"] isKindOfClass:[NSString class]]) {
                         errorUserInfo[@"remoteStatus"] = errorDictionary[@"status"];
                       }
                       if (errorDictionary[@"code"] &&
                           [errorDictionary[@"code"] isKindOfClass:[NSNumber class]]) {
                         errorUserInfo[@"remoteErrorCode"] = errorDictionary[@"code"];
                       }
                       error = [NSError errorWithDomain:kFirebaseDurableDeepLinkErrorDomain
                                                   code:0
                                               userInfo:errorUserInfo];
                     }
                   }
                   if ([JSONObject[@"warning"] isKindOfClass:[NSArray class]]) {
                     NSArray *warningsServer = JSONObject[@"warning"];
                     NSMutableArray *warningsTmp =
                         [NSMutableArray arrayWithCapacity:[warningsServer count]];
                     for (NSDictionary *warningServer in warningsServer) {
                       if ([warningServer[@"warningMessage"] isKindOfClass:[NSString class]]) {
                         [warningsTmp addObject:warningServer[@"warningMessage"]];
                       }
                     }
                     if ([warningsTmp count] > 0) {
                       warnings = [warningsTmp copy];
                     }
                   }
                 } else if (deserializationError) {
                   error = [NSError
                       errorWithDomain:kFirebaseDurableDeepLinkErrorDomain
                                  code:0
                              userInfo:@{
                                NSLocalizedFailureReasonErrorKey : NSLocalizedString(
                                    @"Unrecognized server response",
                                    @"Error reason message when server response can't be parsed"),
                                NSUnderlyingErrorKey : deserializationError,
                              }];
                 }
               }
               if (!shortURL && !error) {
                 // provide generic error message if we have no additional details about failure
                 error = [NSError errorWithDomain:kFirebaseDurableDeepLinkErrorDomain
                                             code:0
                                         userInfo:nil];
               }
               dispatch_async(dispatch_get_main_queue(), ^{
                 completion(shortURL, warnings, error);
               });
             }];
}

- (void)shortenWithCompletion:(FIRDynamicLinkShortenerCompletion)completion {
  NSURL *url = [self url];
  if (!url) {
    NSError *error = [NSError errorWithDomain:kFirebaseDurableDeepLinkErrorDomain
                                         code:0
                                     userInfo:@{
                                       NSLocalizedFailureReasonErrorKey : NSLocalizedString(
                                           @"Unable to produce long URL",
                                           @"Error reason when long url can't be produced"),
                                     }];
    completion(nil, nil, error);
    return;
  }
  return [FIRDynamicLinkComponents shortenURL:url options:_options completion:completion];
}

- (NSURL *)url {
  static NSString *const kFDLURLComponentsLinkKey = @"link";

  NSMutableDictionary *queryDictionary =
      [NSMutableDictionary dictionaryWithObject:self.link.absoluteString
                                         forKey:kFDLURLComponentsLinkKey];

  void (^addEntriesFromDictionaryRepresentingConformerToDictionary)(id<FDLDictionaryRepresenting>) =
      ^(id<FDLDictionaryRepresenting> _Nullable dictionaryRepresentingConformer) {
        NSDictionary *dictionary = dictionaryRepresentingConformer.dictionaryRepresentation;
        if (dictionary.count > 0) {
          [queryDictionary addEntriesFromDictionary:dictionary];
        }
      };

  addEntriesFromDictionaryRepresentingConformerToDictionary(_analyticsParameters);
  addEntriesFromDictionaryRepresentingConformerToDictionary(_socialMetaTagParameters);
  addEntriesFromDictionaryRepresentingConformerToDictionary(_iOSParameters);
  addEntriesFromDictionaryRepresentingConformerToDictionary(_iTunesConnectParameters);
  addEntriesFromDictionaryRepresentingConformerToDictionary(_androidParameters);
  addEntriesFromDictionaryRepresentingConformerToDictionary(_navigationInfoParameters);
  addEntriesFromDictionaryRepresentingConformerToDictionary(_otherPlatformParameters);

  NSString *queryString = FIRDLURLQueryStringFromDictionary(queryDictionary);
  NSString *urlString = [NSString stringWithFormat:@"%@/%@", _domain, queryString];
  return [NSURL URLWithString:urlString];
}

#pragma mark Helper Methods

+ (void)sendHTTPRequest:(NSURLRequest *)request
             completion:(void (^)(NSData *_Nullable data, NSError *_Nullable error))completion {
  NSURLSession *session = [NSURLSession sharedSession];
  NSURLSessionDataTask *task =
      [session dataTaskWithRequest:request
                 completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                                     NSError *_Nullable error) {
                   completion(data, error);
                 }];
  [task resume];
}

+ (NSURLRequest *)shorteningRequestForLongURL:(NSURL *)url
                                      options:(nullable FIRDynamicLinkComponentsOptions *)options {
  if (!url) {
    return nil;
  }

  static NSString *const kFDLURLShortenerAPIHost = @"https://firebasedynamiclinks.googleapis.com";
  static NSString *const kFDLURLShortenerAPIPath = @"/v1/shortLinks";
  static NSString *const kFDLURLShortenerAPIQuery = @"?key=";

  NSString *apiKey = [FIRDynamicLinkComponentsKeyProvider APIKey];

  NSString *postURLString =
      [NSString stringWithFormat:@"%@%@%@%@", kFDLURLShortenerAPIHost, kFDLURLShortenerAPIPath,
                                 kFDLURLShortenerAPIQuery, apiKey];
  NSURL *postURL = [NSURL URLWithString:postURLString];

  NSMutableDictionary *payloadDictionary =
      [NSMutableDictionary dictionaryWithObject:url.absoluteString forKey:@"longDynamicLink"];
  switch (options.pathLength) {
    case FIRShortDynamicLinkPathLengthShort:
      payloadDictionary[@"suffix"] = @{@"option" : @"SHORT"};
      break;
    case FIRShortDynamicLinkPathLengthUnguessable:
      payloadDictionary[@"suffix"] = @{@"option" : @"UNGUESSABLE"};
      break;
    default:
      break;
  }
  NSData *payload = [NSJSONSerialization dataWithJSONObject:payloadDictionary options:0 error:0];

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:postURL];
  request.HTTPMethod = @"POST";
  request.HTTPBody = payload;
  [request setValue:[NSBundle mainBundle].bundleIdentifier
      forHTTPHeaderField:@"X-Ios-Bundle-Identifier"];
  NSString *contentType = @"application/json";
  [request setValue:contentType forHTTPHeaderField:@"Accept"];
  [request setValue:contentType forHTTPHeaderField:@"Content-Type"];

  return [request copy];
}

@end

#endif  // TARGET_OS_IOS
