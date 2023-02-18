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
#import "FirebaseRemoteConfig/Sources/RCNConfigRealtime.h"
#import "FirebaseRemoteConfigSwift/Tests/ObjC/RealtimeMocks.h"

@interface RCNConfigRealtime (ExposedForTest)
- (FIRConfigUpdateListenerRegistration *_Nonnull)addOnConfigUpdateListener: (FIRRemoteConfigUpdateCompletion _Nonnull)listener;

- (void)fetchLatestConfig:(NSInteger)remainingAttempts targetVersion:(NSInteger)targetVersion;

- (void)beginRealtimeStream;

@end

@implementation RealtimeMocks

(RCNConfigRealtime *)mockRealtime:(RCNConfigRealtime *)configRealtime {
    RCNConfigRealtime *mockRealtime = OCMPartialMock(configRealtime);
    OCMStub([mockRealtime recreateNetworkSession]).andDo(nil);
    OCMStub([mockRealtime beginRealtimeStream]).andCall(mockRealtime, @selector(fetchLatestConfig:1 targetVersion:1))
    
}

@end
