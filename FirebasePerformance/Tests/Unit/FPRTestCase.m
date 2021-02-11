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

#import "FirebasePerformance/Tests/Unit/FPRTestCase.h"

#import "FirebasePerformance/Sources/Configurations/FPRConfigurations+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags+Private.h"

@implementation FPRTestCase

- (void)setUp {
  [super setUp];
  self.appFake = [FIRAppFake defaultApp];
  [FPRConfigurations sharedInstance].FIRAppClass = [FIRAppFake class];
  [[FPRRemoteConfigFlags sharedInstance] resetCache];
}

- (void)tearDown {
  [FPRConfigurations reset];
  [FIRAppFake reset];
  [super tearDown];
}

@end
