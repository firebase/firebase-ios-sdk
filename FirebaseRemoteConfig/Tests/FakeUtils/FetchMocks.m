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

#import <OCMock/OCMock.h>

#import "FirebaseRemoteConfig/Sources/Private/RCNConfigFetch.h"
#import "FirebaseRemoteConfig/Tests/FakeUtils/FetchMocks.h"

@interface RCNConfigFetch (ExposedForTest)
- (void)refreshInstallationsTokenWithCompletionHandler:
    (FIRRemoteConfigFetchCompletion)completionHandler;
- (void)doFetchCall:(FIRRemoteConfigFetchCompletion)completionHandler;
@end

@implementation FetchMocks

+ (RCNConfigFetch *)mockFetch:(RCNConfigFetch *)fetch {
  RCNConfigFetch *mock = OCMPartialMock(fetch);
  OCMStub([mock recreateNetworkSession]).andDo(nil);
  OCMStub([mock refreshInstallationsTokenWithCompletionHandler:[OCMArg any]])
      .andCall(mock, @selector(doFetchCall:));
  return mock;
}

@end
