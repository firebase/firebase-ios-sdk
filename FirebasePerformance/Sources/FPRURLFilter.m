// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FirebasePerformance/Sources/FPRURLFilter.h"
#import "FirebasePerformance/Sources/FPRURLFilter_Private.h"

#import "FirebasePerformance/Sources/FPRConsoleLogger.h"

#import <GoogleDataTransport/GoogleDataTransport.h>

/** The expected key of the domain allowlist array. */
static NSString *const kFPRAllowlistDomainsKey = @"FPRWhitelistedDomains";

/** Allowlist status enums. */
typedef NS_ENUM(NSInteger, FPRURLAllowlistStatus) {

  /** No allowlist is present, so the URL will be allowed. */
  FPRURLAllowlistStatusDoesNotExist = 1,

  /** The URL is allowed. */
  FPRURLAllowlistStatusAllowed = 2,

  /** The URL is NOT allowed. */
  FPRURLAllowlistStatusNotAllowed = 3
};

/** Returns the set of denied URL strings.
 *
 *  @return the set of denied URL strings.
 */
NSSet<NSString *> *GetSystemDenyListURLStrings(void) {
  // The denylist of URLs for uploading events to avoid cyclic generation of those network events.
  static NSSet *denylist = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    denylist = [[NSSet alloc] initWithArray:@[
      [[GDTCOREndpoints uploadURLForTarget:kGDTCORTargetCCT] absoluteString],
      [[GDTCOREndpoints uploadURLForTarget:kGDTCORTargetFLL] absoluteString]
    ]];
  });
  return denylist;
}

@implementation FPRURLFilter

+ (instancetype)sharedInstance {
  static FPRURLFilter *sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[FPRURLFilter alloc] initWithBundle:[NSBundle mainBundle]];
  });
  return sharedInstance;
}

- (instancetype)initWithBundle:(NSBundle *)bundle {
  self = [super init];
  if (self) {
    _mainBundle = bundle;
    _allowlistDomains = [self retrieveAllowlistFromPlist];
  }

  return self;
}

- (BOOL)shouldInstrumentURL:(NSString *)URL {
  if ([self isURLDeniedByTheSDK:URL]) {
    return NO;
  }
  FPRURLAllowlistStatus allowlistStatus = [self isURLAllowed:URL];
  if (allowlistStatus == FPRURLAllowlistStatusDoesNotExist) {
    return YES;
  }
  return allowlistStatus == FPRURLAllowlistStatusAllowed;
}

#pragma mark - Private helper methods

/** Determines if the URL is denied by the SDK.
 *
 *  @param URL the URL string to check.
 *  @return YES if the URL is allowed by the SDK, NO otherwise.
 */
- (BOOL)isURLDeniedByTheSDK:(NSString *)URL {
  BOOL shouldDenyURL = NO;

  for (NSString *denyListURL in GetSystemDenyListURLStrings()) {
    if ([URL hasPrefix:denyListURL]) {
      shouldDenyURL = YES;
      break;
    }
  }

  return shouldDenyURL;
}

/** Determines if the URL is allowed by the Developer.
 *
 *  @param URL The URL string to check.
 *  @return FPRURLAllowlistStatusAllowed if the URL is allowed,
 *      FPRURLAllowlistStatusNotAllowed if the URL is not allowed, or
 *      FPRURLAllowlistStatusDoesNotExist if the allowlist does not exist.
 */
- (FPRURLAllowlistStatus)isURLAllowed:(NSString *)URL {
  if (self.allowlistDomains && !self.disablePlist) {
    for (NSString *allowlistDomain in self.allowlistDomains) {
      NSURLComponents *components = [[NSURLComponents alloc] initWithString:URL];
      if ([components.host containsString:allowlistDomain]) {
        return FPRURLAllowlistStatusAllowed;
      }
    }
    return FPRURLAllowlistStatusNotAllowed;
  }
  return FPRURLAllowlistStatusDoesNotExist;
}

/** Retrieves the allowlist from an Info.plist.
 *
 *  @return An array of the allowlist values, or nil if the allowlist key is not found.
 */
- (nullable NSArray<NSString *> *)retrieveAllowlistFromPlist {
  NSArray<NSString *> *allowlist = nil;
  id plistObject = [self.mainBundle objectForInfoDictionaryKey:kFPRAllowlistDomainsKey];
  if (!plistObject) {
    NSBundle *localBundle = [NSBundle bundleForClass:[self class]];
    plistObject = [localBundle objectForInfoDictionaryKey:kFPRAllowlistDomainsKey];
  }
  if ([plistObject isKindOfClass:[NSArray class]]) {
    FPRLogInfo(kFPRURLAllowlistingEnabled, @"A domain allowlist was detected. Domains not "
                                            "explicitly allowlisted will not be instrumented.");
    allowlist = plistObject;
  }

  return allowlist;
}

@end
