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

#import "FIRCLSRecordThread.h"
#import "FIRCLSRecordFrame.h"
#import "FIRCLSRecordRegister.h"
#import "FIRCLSRecordRuntime.h"

@implementation FIRCLSRecordThread

+ (NSArray<FIRCLSRecordThread *> *)threadsFromDictionaries:(NSArray *)threads
                                                 withNames:(NSArray *)names
                                               withRuntime:(FIRCLSRecordRuntime *)runtime {
  NSMutableArray<FIRCLSRecordThread *> *result =
      [[NSMutableArray<FIRCLSRecordThread *> alloc] init];
  for (int i = 0; i < threads.count; i++) {
    FIRCLSRecordThread *thread = [[FIRCLSRecordThread alloc] initWithDict:threads[i]];

    if (thread.crashed && runtime.objc_selector.length > 0) {
      thread.objc_selector_name = runtime.objc_selector;
    }

    if (i < names.count) {
      thread.name = names[i];
    }

    [result addObject:thread];
  }

  return result;
}

- (instancetype)initWithDict:(NSDictionary *)dict {
  self = [super initWithDict:dict];
  if (self) {
    _alternate_name = dict[@"alternate_name"];
    _crashed = [dict[@"crashed"] boolValue];
    _stacktrace = dict[@"stacktrace"];
    _registers = [FIRCLSRecordRegister registersFromDictionary:dict[@"registers"]];
  }
  return self;
}

@end
