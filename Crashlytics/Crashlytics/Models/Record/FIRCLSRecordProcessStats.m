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
    _active = (NSUInteger)dict[@"active"];
    _inactive = (NSUInteger)dict[@"inactive"];
    _wired = (NSUInteger)dict[@"wired"];
    _freeMem = (NSUInteger)dict[@"freeMem"];
    _virtualAddress = (NSUInteger)dict[@"virtual"];
    _resident = (NSUInteger)dict[@"resident"];
    _user_time = (NSUInteger)dict[@"user_time"];
    _sys_time = (NSUInteger)dict[@"user_time"];
  }
  return self;
}

@end
