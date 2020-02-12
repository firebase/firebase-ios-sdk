// Copyright 2020 Google
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

#import "FIRCLSRecordMachException.h"

@interface FIRCLSRecordMachException ()

@property(nonatomic, readwrite) NSMutableArray<NSNumber *> *codes;

@end

@implementation FIRCLSRecordMachException

- (instancetype)initWithDict:(NSDictionary *)dict {
  self = [super initWithDict:dict];
  if (!self) {
    return self;
  }

  _codes = [[NSMutableArray alloc] init];
  for (NSNumber *codeNumber in dict[@"codes"]) {
    [_codes addObject:codeNumber];
  }

  _code_name = dict[@"code_name"];
  _name = dict[@"name"];

  _exception = [dict[@"exception"] unsignedIntegerValue];
  _original_ports = [dict[@"original_ports"] unsignedIntegerValue];

  self.time = [dict[@"time"] unsignedIntegerValue];

  return self;
}

@end
