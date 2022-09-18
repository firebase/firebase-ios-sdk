// Copyright 2022 Google LLC
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

#import "Crashlytics/Crashlytics/Models/FIRCLSOnDemandModel.h"
#import "Crashlytics/Crashlytics/Private/FIRCLSOnDemandModel_Private.h"

@interface FIRCLSMockOnDemandModel : FIRCLSOnDemandModel

- (instancetype)initWithFIRCLSSettings:(FIRCLSSettings *)settings
                           fileManager:(FIRCLSFileManager *)fileManager
                            sleepBlock:(void (^)(int))sleepBlock;

// Public for testing purposes
- (void)setQueueToFull;
- (void)setQueueToEmpty;
- (int)getQueueMax;

@property(nonatomic, copy) void (^sleepBlock)(int);

@end
