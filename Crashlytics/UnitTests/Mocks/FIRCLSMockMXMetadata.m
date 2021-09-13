// Copyright 2021 Google LLC
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

#if CLS_METRICKIT_SUPPORTED

@interface FIRCLSMockMXMetadata ()
@property(readwrite, strong, nonnull) NSString *regionFormat;
@property(readwrite, strong, nonnull) NSString *osVersion;
@property(readwrite, strong, nonnull) NSString *deviceType;
@property(readwrite, strong, nonnull) NSString *applicationBuildVersion;
@property(readwrite, strong, nonnull) NSString *platformArchitecture;
@end

@implementation FIRCLSMockMXMetadata

@synthesize regionFormat = _regionFormat;
@synthesize osVersion = _osVersion;
@synthesize deviceType = _deviceType;
@synthesize applicationBuildVersion = _applicationBuildVersion;
@synthesize platformArchitecture = _platformArchitecture;

- (instancetype)initWithRegionFormat:(NSString *)regionFormat
                           osVersion:(NSString *)osVersion
                          deviceType:(NSString *)deviceType
             applicationBuildVersion:(NSString *)applicationBuildVersion
                platformArchitecture:(NSString *)platformArchitecture {
  self = [super init];
  _regionFormat = regionFormat;
  _osVersion = osVersion;
  _deviceType = deviceType;
  _applicationBuildVersion = applicationBuildVersion;
  _platformArchitecture = platformArchitecture;
  return self;
}

- (NSData *)JSONRepresentation {
  NSDictionary *metadata = @{
    @"appBuildVersion" : self.applicationBuildVersion,
    @"osVersion" : self.osVersion,
    @"regionFormat" : self.regionFormat,
    @"platformArchitecture" : self.platformArchitecture,
    @"deviceType" : self.deviceType
  };
  return [NSJSONSerialization dataWithJSONObject:metadata options:0 error:nil];
}

@end

#endif
