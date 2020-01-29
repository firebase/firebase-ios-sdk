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

#import "FIRCLSRecordKeyValue.h"
#import "FIRCLSFile.h"

@implementation FIRCLSRecordKeyValue

+ (NSArray<FIRCLSRecordKeyValue *> *)keyValuesFromDictionaries:(NSArray<NSDictionary *> *)dicts {
  NSMutableArray<FIRCLSRecordKeyValue *> *keyValues =
      [[NSMutableArray<FIRCLSRecordKeyValue *> alloc] init];
  for (NSDictionary *dict in dicts) {
    [keyValues addObject:[[FIRCLSRecordKeyValue alloc] initWithDict:dict[@"kv"]]];
  }
  return keyValues;
}

- (instancetype)initWithDict:(NSDictionary *)dict {
  self = [super initWithDict:dict];
  if (self) {
    NSString *key = dict[@"key"];
    if (key) {
      _key = FIRCLSFileHexDecodeString([key UTF8String]);
    }

    NSString *value = dict[@"value"];
    if (value) {
      _value = FIRCLSFileHexDecodeString([value UTF8String]);
    }
  }
  return self;
}

@end
