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

#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"

@interface FIRMockInstallations : FIRInstallations

@property(nonatomic) BOOL authTokenFinished;
@property(nonatomic) BOOL installationIDFinished;

- (instancetype)initWithFID:(NSString *)installationID;
- (instancetype)initWithError:(NSError *)error;

@end
