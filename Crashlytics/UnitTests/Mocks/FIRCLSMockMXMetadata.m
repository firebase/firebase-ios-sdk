// Copyright 2021 Google
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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXMetadata.h"

@implementation FIRCLSMockMXMetadata

- (instancetype)initWithRegionFormat:(NSString *)regionFormat
                           osVersion:(NSString *)osVersion
                          deviceType:(NSString *)deviceType
             applicationBuildVersion:(NSString *)applicationBuildVersion
                platformArchitecture:(NSString *)platformArchitecture {
  self.regionFormat = regionFormat;
  self.osVersion = osVersion;
  self.deviceType = deviceType;
  self.applicationBuildVersion = applicationBuildVersion;
  self.platformArchitecture = platformArchitecture;
  return self;
}

@end
