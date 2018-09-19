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

#import "DynamicLinks/FIRDynamicLink+Private.h"

#import "DynamicLinks/Utilities/FDLUtilities.h"

@implementation FIRDynamicLink

- (NSString *)description {
  return [NSString stringWithFormat:
                       @"<%@: %p, url [%@], match type: %@, minimumAppVersion: %@, "
                        "match message: %@>",
                       NSStringFromClass([self class]), self, self.url,
                       [[self class] stringWithMatchType:_matchType],
                       self.minimumAppVersion ?: @"N/A", self.matchMessage];
}

- (instancetype)initWithParametersDictionary:(NSDictionary *)parameters {
  NSParameterAssert(parameters.count > 0);

  if (self = [super init]) {
    NSString *urlString = parameters[kFIRDLParameterDeepLinkIdentifier];
    _url = [NSURL URLWithString:urlString];
    _inviteId = parameters[kFIRDLParameterInviteId];
    _weakMatchEndpoint = parameters[kFIRDLParameterWeakMatchEndpoint];
    _minimumAppVersion = parameters[kFIRDLParameterMinimumAppVersion];

    if (parameters[kFIRDLParameterMatchType]) {
      _matchType = [[self class] matchTypeWithString:parameters[kFIRDLParameterMatchType]];
    } else if (_url || _inviteId) {
      // If matchType not present assume unique match for compatibility with server side behavior
      // on iOS 8.
      _matchType = FIRDLMatchTypeUnique;
    }
    _matchMessage = parameters[kFIRDLParameterMatchMessage];
  }
  return self;
}

- (NSDictionary *)parametersDictionary {
  NSMutableDictionary *parametersDictionary = [NSMutableDictionary dictionary];
  parametersDictionary[kFIRDLParameterInviteId] = _inviteId;
  parametersDictionary[kFIRDLParameterDeepLinkIdentifier] = [_url absoluteString];
  parametersDictionary[kFIRDLParameterMatchType] = [[self class] stringWithMatchType:_matchType];
  parametersDictionary[kFIRDLParameterWeakMatchEndpoint] = _weakMatchEndpoint;
  parametersDictionary[kFIRDLParameterMinimumAppVersion] = _minimumAppVersion;
  parametersDictionary[kFIRDLParameterMatchMessage] = _matchMessage;
  return parametersDictionary;
}

- (FIRDynamicLinkMatchConfidence)matchConfidence {
  return (_matchType == FIRDLMatchTypeUnique) ? FIRDynamicLinkMatchConfidenceStrong
                                              : FIRDynamicLinkMatchConfidenceWeak;
}

+ (NSString *)stringWithMatchType:(FIRDLMatchType)matchType {
  switch (matchType) {
    case FIRDLMatchTypeNone:
      return @"none";
    case FIRDLMatchTypeWeak:
      return @"weak";
    case FIRDLMatchTypeDefault:
      return @"default";
    case FIRDLMatchTypeUnique:
      return @"unique";
  }
}

+ (FIRDLMatchType)matchTypeWithString:(NSString *)string {
  static NSDictionary *matchMap;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    matchMap = @{
      @"none" : @(FIRDLMatchTypeNone),
      @"weak" : @(FIRDLMatchTypeWeak),
      @"default" : @(FIRDLMatchTypeDefault),
      @"unique" : @(FIRDLMatchTypeUnique),
    };
  });
  return [matchMap[string] integerValue] ?: FIRDLMatchTypeNone;
}

@end
