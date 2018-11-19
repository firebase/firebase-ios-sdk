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

#import "DynamicLinks/Utilities/FDLUtilities.h"

#import <UIKit/UIDevice.h>
#include <sys/sysctl.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const kFIRDLParameterDeepLinkIdentifier = @"deep_link_id";
NSString *const kFIRDLParameterLink = @"link";
NSString *const kFIRDLParameterMinimumAppVersion = @"imv";
NSString *const kFIRDLParameterSource = @"utm_source";
NSString *const kFIRDLParameterMedium = @"utm_medium";
NSString *const kFIRDLParameterCampaign = @"utm_campaign";
NSString *const kFIRDLParameterMatchType = @"match_type";
NSString *const kFIRDLParameterInviteId = @"invitation_id";
NSString *const kFIRDLParameterWeakMatchEndpoint = @"invitation_weakMatchEndpoint";
NSString *const kFIRDLParameterMatchMessage = @"match_message";
NSString *const kFIRDLParameterRequestIPVersion = @"request_ip_version";

NSURL *FIRDLCookieRetrievalURL(NSString *urlScheme, NSString *bundleID) {
  static NSString *const kFDLBundleIDQueryParameterName = @"fdl_ios_bundle_id";
  static NSString *const kFDLURLSchemeQueryParameterName = @"fdl_ios_url_scheme";

  NSURLComponents *components = [[NSURLComponents alloc] init];
  components.scheme = @"https";
  components.host = @"goo.gl";
  components.path = @"/app/_/deeplink";
  NSMutableArray *queryItems = [NSMutableArray array];

  [queryItems
      addObject:[NSURLQueryItem queryItemWithName:kFDLBundleIDQueryParameterName value:bundleID]];
  [queryItems
      addObject:[NSURLQueryItem queryItemWithName:kFDLURLSchemeQueryParameterName value:urlScheme]];
  [components setQueryItems:queryItems];

  return [components URL];
}

NSString *FIRDLURLQueryStringFromDictionary(NSDictionary<NSString *, NSString *> *dictionary) {
  NSMutableString *parameters = [NSMutableString string];

  NSCharacterSet *queryCharacterSet = [NSCharacterSet alphanumericCharacterSet];
  NSString *parameterFormatString = @"%@%@=%@";
  __block NSUInteger index = 0;
  [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSString *_Nonnull value,
                                                  BOOL *_Nonnull stop) {
    NSString *delimiter = index++ == 0 ? @"?" : @"&";
    NSString *encodedValue =
        [value stringByAddingPercentEncodingWithAllowedCharacters:queryCharacterSet];
    NSString *parameter =
        [NSString stringWithFormat:parameterFormatString, delimiter, key, encodedValue];
    [parameters appendString:parameter];
  }];

  return parameters;
}

NSDictionary *FIRDLDictionaryFromQuery(NSString *queryString) {
  NSArray<NSString *> *keyValuePairs = [queryString componentsSeparatedByString:@"&"];

  NSMutableDictionary *queryDictionary =
      [NSMutableDictionary dictionaryWithCapacity:keyValuePairs.count];

  for (NSString *pair in keyValuePairs) {
    NSArray *keyValuePair = [pair componentsSeparatedByString:@"="];
    if (keyValuePair.count == 2) {
      NSString *key = keyValuePair[0];
      NSString *value = [keyValuePair[1] stringByRemovingPercentEncoding];
      [queryDictionary setObject:value forKey:key];
    }
  }

  return [queryDictionary copy];
}

NSURL *FIRDLDeepLinkURLWithInviteID(NSString *_Nullable inviteID,
                                    NSString *_Nullable deepLinkString,
                                    NSString *_Nullable utmSource,
                                    NSString *_Nullable utmMedium,
                                    NSString *_Nullable utmCampaign,
                                    BOOL isWeakLink,
                                    NSString *_Nullable weakMatchEndpoint,
                                    NSString *_Nullable minAppVersion,
                                    NSString *URLScheme,
                                    NSString *_Nullable matchMessage) {
  // We are unable to use NSURLComponents as NSURLQueryItem is avilable beginning in iOS 8 and
  // appending our query string with NSURLComponents improperly formats the query by adding
  // a second '?' in the query.
  NSMutableDictionary *queryDictionary = [NSMutableDictionary dictionary];
  if (inviteID != nil) {
    queryDictionary[kFIRDLParameterInviteId] = inviteID;
  }
  if (deepLinkString != nil) {
    queryDictionary[kFIRDLParameterDeepLinkIdentifier] = deepLinkString;
  }
  if (utmSource != nil) {
    queryDictionary[kFIRDLParameterSource] = utmSource;
  }
  if (utmMedium != nil) {
    queryDictionary[kFIRDLParameterMedium] = utmMedium;
  }
  if (utmCampaign != nil) {
    queryDictionary[kFIRDLParameterCampaign] = utmCampaign;
  }
  if (isWeakLink) {
    queryDictionary[kFIRDLParameterMatchType] = @"weak";
  } else {
    queryDictionary[kFIRDLParameterMatchType] = @"unique";
  }
  if (weakMatchEndpoint != nil) {
    queryDictionary[kFIRDLParameterWeakMatchEndpoint] = weakMatchEndpoint;
  }
  if (minAppVersion != nil) {
    queryDictionary[kFIRDLParameterMinimumAppVersion] = minAppVersion;
  }
  if (matchMessage != nil) {
    queryDictionary[kFIRDLParameterMatchMessage] = matchMessage;
  }

  NSString *scheme = [URLScheme lowercaseString];
  NSString *queryString = FIRDLURLQueryStringFromDictionary(queryDictionary);
  NSString *urlString = [NSString stringWithFormat:@"%@://google/link/%@", scheme, queryString];

  return [NSURL URLWithString:urlString];
}

BOOL FIRDLOSVersionSupported(NSString *_Nullable systemVersion, NSString *minSupportedVersion) {
  systemVersion = systemVersion ?: [UIDevice currentDevice].systemVersion;
  return [systemVersion compare:minSupportedVersion options:NSNumericSearch] != NSOrderedAscending;
}

NSDate *_Nullable FIRDLAppInstallationDate() {
  NSURL *documentsDirectoryURL =
      [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                              inDomains:NSUserDomainMask] firstObject];
  if (!documentsDirectoryURL) {
    return nil;
  }
  NSDictionary<NSString *, id> *attributes =
      [[NSFileManager defaultManager] attributesOfItemAtPath:documentsDirectoryURL.path error:NULL];
  if (attributes[NSFileCreationDate] &&
      [attributes[NSFileCreationDate] isKindOfClass:[NSDate class]]) {
    return attributes[NSFileCreationDate];
  }
  return nil;
}

NSString *FIRDLDeviceModelName() {
  // this method will return string like iPad3,3
  // for Simulator this will be x86_64
  static NSString *machineString;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = calloc(1, size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    machineString = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
  });
  return machineString;
}

NSString *FIRDLDeviceLocale() {
  // expected return value from this method looks like: @"en-US"
  return [[[NSLocale currentLocale] localeIdentifier] stringByReplacingOccurrencesOfString:@"_"
                                                                                withString:@"-"];
}

NSString *FIRDLDeviceLocaleRaw() {
  return [[NSLocale currentLocale] localeIdentifier];
}

NSString *FIRDLDeviceTimezone() {
  NSString *timeZoneName = [[NSTimeZone localTimeZone] name];
  return timeZoneName;
}

BOOL FIRDLCanParseUniversalLinkURL(NSURL *_Nullable URL) {
  // Handle universal links with format |https://goo.gl/app/<appcode>?<parameters>|.
  // Also support page.link format.
  BOOL isDDLWithAppcodeInPath = ([URL.host isEqual:@"goo.gl"] || [URL.host isEqual:@"page.link"]) &&
                                [URL.path hasPrefix:@"/app"];
  // Handle universal links with format |https://<appcode>.app.goo.gl?<parameters>| and page.link.
  BOOL isDDLWithSubdomain =
      [URL.host hasSuffix:@".app.goo.gl"] || [URL.host hasSuffix:@".page.link"];
  return isDDLWithAppcodeInPath || isDDLWithSubdomain;
}

BOOL FIRDLMatchesShortLinkFormat(NSURL *URL) {
  // Short Durable Link URLs always have a path.
  BOOL hasPath = URL.path.length > 0;
  // Must be able to parse (also checks if the URL conforms to *.app.goo.gl/* or goo.gl/app/*)
  BOOL canParse = FIRDLCanParseUniversalLinkURL(URL);
  // Path cannot be prefixed with /link/dismiss
  BOOL isDismiss = [[URL.path lowercaseString] hasPrefix:@"/link/dismiss"];

  return hasPath && !isDismiss && canParse;
}

NSString *FIRDLMatchTypeStringFromServerString(NSString *_Nullable serverMatchTypeString) {
  static NSDictionary *matchMap;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    matchMap = @{
      @"WEAK" : @"weak",
      @"DEFAULT" : @"default",
      @"UNIQUE" : @"unique",
    };
  });
  return matchMap[serverMatchTypeString] ?: @"none";
}

NS_ASSUME_NONNULL_END
