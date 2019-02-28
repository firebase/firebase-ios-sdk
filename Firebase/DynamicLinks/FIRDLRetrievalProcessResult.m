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

#import "DynamicLinks/FIRDLRetrievalProcessResult.h"
#import "DynamicLinks/FIRDLRetrievalProcessResult+Private.h"
#import "DynamicLinks/FIRDynamicLink+Private.h"
#import "DynamicLinks/Utilities/FDLUtilities.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRDLRetrievalProcessResult

- (instancetype)initWithDynamicLink:(nullable FIRDynamicLink *)dynamicLink
                             source:(nullable NSString *)source
                             medium:(nullable NSString *)medium
                           campaign:(nullable NSString *)campaign
                              error:(nullable NSError *)error
                            message:(nullable NSString *)message
                        matchSource:(nullable NSString *)matchSource {
  if (self = [super init]) {
    _dynamicLink = dynamicLink;
    _source = [source copy];
    _medium = [medium copy];
    _campaign = [campaign copy];
    _error = error;
    _message = [message copy];
    _matchSource = [matchSource copy];
  }
  return self;
}

- (NSURL *)URLWithCustomURLScheme:(NSString *)customURLScheme {
  NSURL *URL;
  if (_dynamicLink) {
    NSString *queryString = FIRDLURLQueryStringFromDictionary(_dynamicLink.parametersDictionary);
    NSString *utmFormatString = @"&utm_medium=%@&utm_campaign=%@&utm_source=%@";
    NSString *queryStringUtm = [NSString stringWithFormat:utmFormatString, _medium, _campaign, _source];
    NSMutableString *URLString = [[NSMutableString alloc] init];
    [URLString appendString:customURLScheme];
    [URLString appendString:@"://google/link/"];
    [URLString appendString:queryString];
    [URLString appendString:queryStringUtm];
    URL = [NSURL URLWithString:URLString];
  } else {
    NSMutableString *URLString = [[NSMutableString alloc] init];
    [URLString appendString:customURLScheme];
    [URLString appendString:@"://google/link/?dismiss=1&is_weak_match=1"];
    URL = [NSURL URLWithString:URLString];
  }
  return URL;
}

@end

NS_ASSUME_NONNULL_END
