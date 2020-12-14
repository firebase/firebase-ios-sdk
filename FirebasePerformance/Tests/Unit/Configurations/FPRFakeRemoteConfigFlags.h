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

#import <Foundation/Foundation.h>
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags.h"

NS_ASSUME_NONNULL_BEGIN

@interface FPRFakeRemoteConfigFlags : FPRRemoteConfigFlags

/** A fake representing whether any RC flag value exists. */
@property(nonatomic) BOOL containsRemoteConfigFlagValues;

@end

NS_ASSUME_NONNULL_END
