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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXCallStackTree.h"

#if CLS_METRICKIT_SUPPORTED

@interface FIRCLSMockMXCallStackTree ()
@property(readwrite, strong, nonnull) NSData *jsonData;
@end

@implementation FIRCLSMockMXCallStackTree

- (instancetype)initWithStringData:(NSString *)stringData {
  self = [super init];
  _jsonData = [stringData dataUsingEncoding:NSUTF8StringEncoding];
  return self;
}

- (NSData *)JSONRepresentation {
  return self.jsonData;
}

@end

#endif
