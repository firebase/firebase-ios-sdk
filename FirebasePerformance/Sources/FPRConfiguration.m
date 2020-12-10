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

#import "FirebasePerformance/Sources/FPRConfiguration.h"

#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"

@implementation FPRConfiguration

- (instancetype)init {
  FPRAssert(NO, @"init called on NS_UNAVAILABLE init");
  return nil;
}

- (instancetype)initWithAppID:(NSString *)appID APIKey:(NSString *)APIKey autoPush:(BOOL)autoPush {
  self = [super init];
  if (self) {
    _appID = [appID copy];
    _APIKey = [APIKey copy];
    _autoPush = autoPush;
  }

  return self;
}

+ (instancetype)configurationWithAppID:(NSString *)appID
                                APIKey:(NSString *)APIKey
                              autoPush:(BOOL)autoPush {
  return [[self alloc] initWithAppID:appID APIKey:APIKey autoPush:autoPush];
}

- (id)copyWithZone:(NSZone *)zone {
  return self;  // This class is immutable
}

@end
