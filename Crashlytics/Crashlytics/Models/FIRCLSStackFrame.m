// Copyright 2019 Google
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

#import "FIRCLSStackFrame.h"

@implementation FIRCLSStackFrame

+ (instancetype)stackFrame {
  return [[self alloc] init];
}

+ (instancetype)stackFrameWithAddress:(NSUInteger)address {
  FIRCLSStackFrame* frame = [self stackFrame];

  [frame setAddress:address];

  return frame;
}

+ (instancetype)stackFrameWithSymbol:(NSString*)symbol {
  FIRCLSStackFrame* frame = [self stackFrame];

  frame.symbol = symbol;
  frame.rawSymbol = symbol;

  return frame;
}

- (NSString*)description {
  if ([self fileName]) {
    return [NSString stringWithFormat:@"{[0x%llx] %@ - %@:%u}", [self address], [self fileName],
                                      [self symbol], [self lineNumber]];
  }

  return [NSString
      stringWithFormat:@"{[0x%llx + %u] %@}", [self address], [self lineNumber], [self symbol]];
}

@end
