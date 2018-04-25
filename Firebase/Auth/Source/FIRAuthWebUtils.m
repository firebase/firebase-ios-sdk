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

#import "FIRAuthWebUtils.h"

#import "FIRAuthBackend.h"
#import "FIRAuthErrorUtils.h"
#import "FIRGetProjectConfigRequest.h"
#import "FIRGetProjectConfigResponse.h"

/** @var kAuthDomainSuffix
    @brief The suffix of the auth domain pertiaining to a given Firebase project.
 */
static NSString *const kAuthDomainSuffix = @"firebaseapp.com";

@implementation FIRAuthWebUtils

+ (NSString *)randomStringWithLength:(NSUInteger)length {
  NSMutableString *randomString = [[NSMutableString alloc] init];
  for (int i=0; i < length; i++) {
    [randomString appendString:
        [NSString stringWithFormat:@"%c", 'a' + arc4random_uniform('z' - 'a' + 1)]];
  }
  return randomString;
}

+ (BOOL)isCallbackSchemeRegisteredForCustomURLScheme:(NSString *)URLScheme {
  NSString *expectedCustomScheme = [URLScheme lowercaseString];
  NSArray *urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
  for (NSDictionary *urlType in urlTypes) {
    NSArray *urlTypeSchemes = urlType[@"CFBundleURLSchemes"];
    for (NSString *urlTypeScheme in urlTypeSchemes) {
      if ([urlTypeScheme.lowercaseString isEqualToString:expectedCustomScheme]) {
        return YES;
      }
    }
  }
  return NO;
}

+ (void)fetchAuthDomainWithRequestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration
                                     completion:(FIRFetchAuthDomainCallback)completion {
  FIRGetProjectConfigRequest *request =
      [[FIRGetProjectConfigRequest alloc] initWithRequestConfiguration:requestConfiguration];

  [FIRAuthBackend getProjectConfig:request
                          callback:^(FIRGetProjectConfigResponse *_Nullable response,
                                     NSError *_Nullable error) {
    if (error) {
      completion(nil, error);
      return;
    }
    NSString *authDomain;
    for (NSString *domain in response.authorizedDomains) {
      NSInteger index = domain.length - kAuthDomainSuffix.length;
      if (index >= 2) {
        if ([domain hasSuffix:kAuthDomainSuffix] && domain.length >= kAuthDomainSuffix.length + 2) {
          authDomain = domain;
          break;
        }
      }
    }
    if (!authDomain.length) {
      completion(nil, [FIRAuthErrorUtils unexpectedErrorResponseWithDeserializedResponse:response]);
      return;
    }
    completion(authDomain, nil);
  }];
}

/** @fn queryItemValue:from:
 @brief Utility function to get a value from a NSURLQueryItem array.
 @param name The key.
 @param queryList The NSURLQueryItem array.
 @return The value for the key.
 */

+ (NSString *)queryItemValue:(NSString *)name from:(NSArray<NSURLQueryItem *> *)queryList {
  for (NSURLQueryItem *item in queryList) {
    if ([item.name isEqualToString:name]) {
      return item.value;
    }
  }
  return nil;
}

@end
