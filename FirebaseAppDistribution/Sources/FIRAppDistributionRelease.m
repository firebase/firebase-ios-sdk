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

#import "FIRAppDistributionRelease.h"

@interface FIRAppDistributionRelease ()
@property(nonatomic, copy) NSString *displayVersion;
@property(nonatomic, copy) NSString *buildVersion;
@property(nonatomic, copy) NSString *releaseNotes;
@property(nonatomic, strong) NSURL *downloadURL;
@end

@implementation FIRAppDistributionRelease
- (instancetype)initWithDictionary:(NSDictionary *)dict {
  self = [super init];
  if (self) {
    self.buildVersion = [dict objectForKey:@"buildVersion"];
    self.displayVersion = [dict objectForKey:@"displayVersion"];

    self.downloadURL = [[NSURL alloc] initWithString:[dict objectForKey:@"downloadUrl"]];
    self.releaseNotes = [dict objectForKey:@"releaseNotes"];
  }
  return self;
}
@end
