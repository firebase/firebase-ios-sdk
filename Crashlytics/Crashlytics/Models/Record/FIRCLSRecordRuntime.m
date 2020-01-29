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

#import "FIRCLSRecordRuntime.h"
#import "FIRCLSFile.h"

@implementation FIRCLSRecordRuntime

- (instancetype)initWithDict:(NSDictionary *)dict {
  self = [super initWithDict:dict];
  if (self) {
    _objc_selector = dict[@"objc_selector"] ?: @"";

    NSMutableArray<NSString *> *entries = [[NSMutableArray<NSString *> alloc] init];
    for (NSString *hexString in dict[@"crash_info_entries"]) {
      [entries addObject:FIRCLSFileHexDecodeString([hexString UTF8String])];
    }
    _crash_info_entries = entries;
  }
  return self;
}

@end
