/*
 * Copyright 2020 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FIRCLSRecordProcessStats.h"

@implementation FIRCLSRecordProcessStats

- (instancetype)initWithDict:(NSDictionary *)dict {
  self = [super initWithDict:dict];
  if (self) {
    _active = [dict[@"active"] unsignedIntegerValue];
    _inactive = [dict[@"inactive"] unsignedIntegerValue];
    _wired = [dict[@"wired"] unsignedIntegerValue];
    _freeMem = [dict[@"freeMem"] unsignedIntegerValue];
    _virtualAddress = [dict[@"virtual"] unsignedIntegerValue];
    _resident = [dict[@"resident"] unsignedIntegerValue];
    _user_time = [dict[@"user_time"] unsignedIntegerValue];
    _sys_time = [dict[@"user_time"] unsignedIntegerValue];
  }
  return self;
}

@end
