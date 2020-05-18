/*
 * Copyright 2020 Google LLC
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

#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"
#import "FirebaseRemoteConfig/Sources/Private/RCNFakeFetch.h"

@implementation RCNFakeFetch
static NSMutableDictionary<NSString *, id> *_config = nil;

+(NSDictionary<NSString *, id> *)config {
  return _config;
}

+(void)setConfig:(NSDictionary<NSString *, id> *)newConfig {
  _config = [newConfig mutableCopy];
}

+(BOOL)active {
  return RCNFakeFetch.config && [RCNFakeFetch.config count] > 0;
}

+(NSDictionary<NSString *, id> *) get {
  static NSDictionary<NSString *, id> *last = nil;
  if (_config == nil || _config.count == 0) {
    last = nil;
    return @{RCNFetchResponseKeyState : RCNFetchResponseKeyStateEmptyConfig};
  }
  NSString *state = [_config isEqualToDictionary:last] ? RCNFetchResponseKeyStateNoChange :
                                                         RCNFetchResponseKeyStateUpdate;
  last = _config;
  return @{RCNFetchResponseKeyState : state, RCNFetchResponseKeyEntries: _config};
}

@end
