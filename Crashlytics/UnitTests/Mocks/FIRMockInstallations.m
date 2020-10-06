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

#import "Crashlytics/UnitTests/Mocks/FIRMockInstallations.h"

#import <Foundation/Foundation.h>

@interface FIRMockInstallationsImpl : NSObject

@property(nonatomic, copy) NSString *installationID;
@property(nonatomic, strong) NSError *error;

@end

@implementation FIRMockInstallationsImpl

- (void)installationIDWithCompletion:(FIRInstallationsIDHandler)completion {
  completion(self.installationID, self.error);
}

@end

@interface FIRMockInstallations ()

@property(nonatomic, copy) NSString *instanceID;
@property(nonatomic, strong) NSError *error;

@end

@implementation FIRMockInstallations

- (instancetype)initWithFID:(NSString *)installationID {
  FIRMockInstallationsImpl *mock = [[FIRMockInstallationsImpl alloc] init];
  mock.installationID = [installationID copy];
  mock.error = nil;
  self = (id)mock;
  return self;
}

- (instancetype)initWithError:(NSError *)error {
  FIRMockInstallationsImpl *mock = [[FIRMockInstallationsImpl alloc] init];
  mock.installationID = nil;
  mock.error = error;
  self = (id)mock;
  return self;
}

@end
