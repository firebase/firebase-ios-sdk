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

#import "FirebaseDynamicLinks/Sources/FIRDynamicLink+Private.h"

#import "FirebaseDynamicLinks/Sources/Utilities/FDLUtilities.h"

@implementation FIRDynamicLink

NSString *const FDLUTMParamPrefix = @"utm_";

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@: %p, url [%@], match type: %@, minimumAppVersion: %@, "
                                     "match message: %@>",
                                    NSStringFromClass([self class]), self, self.url,
                                    [[self class] stringWithMatchType:_matchType],
                                    self.minimumAppVersion ?: @"N/A", self.matchMessage];
}

- (instancetype)initWithParametersDictionary:(NSDictionary<NSString *, id> *)parameters {
  NSParameterAssert(parameters.count > 0);

  if (self = [super init]) {
    _parametersDictionary = [parameters copy];
    _utmParametersDictionary = [[self class] extractUTMParams:parameters];
    NSString *urlString = parameters[kFIRDLParameterDeepLinkIdentifier];
    _url = [NSURL URLWithString:urlString];
    _inviteId = parameters[kFIRDLParameterInviteId];
    _weakMatchEndpoint = parameters[kFIRDLParameterWeakMatchEndpoint];
    _minimumAppVersion = parameters[kFIRDLParameterMinimumAppVersion];

    if (parameters[kFIRDLParameterMatchType]) {
      [self setMatchType:[[self class] matchTypeWithString:parameters[kFIRDLParameterMatchType]]];
    } else if (_url || _inviteId) {
      // If matchType not present assume unique match for compatibility with server side behavior
      // on iOS 8.
      [self setMatchType:FIRDLMatchTypeUnique];
    }

    _matchMessage = parameters[kFIRDLParameterMatchMessage];
  }
  return self;
}

#pragma mark - Properties

- (void)setUrl:(NSURL *)url {
  _url = [url copy];
  [self setParametersDictionaryValue:[_url absoluteString]
                              forKey:kFIRDLParameterDeepLinkIdentifier];
}

- (void)setMinimumAppVersion:(NSString *)minimumAppVersion {
  _minimumAppVersion = [minimumAppVersion copy];
  [self setParametersDictionaryValue:_minimumAppVersion forKey:kFIRDLParameterMinimumAppVersion];
}

- (void)setInviteId:(NSString *)inviteId {
  _inviteId = [inviteId copy];
  [self setParametersDictionaryValue:_inviteId forKey:kFIRDLParameterInviteId];
}

- (void)setWeakMatchEndpoint:(NSString *)weakMatchEndpoint {
  _weakMatchEndpoint = [weakMatchEndpoint copy];
  [self setParametersDictionaryValue:_weakMatchEndpoint forKey:kFIRDLParameterWeakMatchEndpoint];
}

- (void)setMatchType:(FIRDLMatchType)matchType {
  _matchType = matchType;
  [self setParametersDictionaryValue:[[self class] stringWithMatchType:_matchType]
                              forKey:kFIRDLParameterMatchType];
}

- (void)setMatchMessage:(NSString *)matchMessage {
  _matchMessage = [matchMessage copy];
  [self setParametersDictionaryValue:_matchMessage forKey:kFIRDLParameterMatchMessage];
}

- (void)setParametersDictionaryValue:(id)value forKey:(NSString *)key {
  NSMutableDictionary<NSString *, id> *parametersDictionary =
      [self.parametersDictionary mutableCopy];
  if (value == nil) {
    [parametersDictionary removeObjectForKey:key];
  } else {
    parametersDictionary[key] = value;
  }

  _parametersDictionary = [parametersDictionary copy];
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

+ (NSDictionary<NSString *, id> *)extractUTMParams:(NSDictionary<NSString *, id> *)parameters {
  NSMutableDictionary<NSString *, id> *utmParamsDictionary = [[NSMutableDictionary alloc] init];

  for (NSString *key in parameters) {
    if ([key hasPrefix:FDLUTMParamPrefix]) {
      [utmParamsDictionary setObject:[parameters valueForKey:key] forKey:key];
    }
  }

  return [[NSDictionary alloc] initWithDictionary:utmParamsDictionary];
}

@end

#endif  // TARGET_OS_IOS
