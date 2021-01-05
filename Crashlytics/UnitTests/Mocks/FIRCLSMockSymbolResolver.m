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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockSymbolResolver.h"

#import "Crashlytics/Crashlytics/Private/FIRStackFrame_Private.h"

@interface FIRCLSMockSymbolResolver () {
  NSMutableDictionary *_frames;
}

@end

@implementation FIRCLSMockSymbolResolver

- (instancetype)init {
  self = [super init];
  if (!self) {
    return nil;
  }

  _frames = [[NSMutableDictionary alloc] init];

  return self;
}

- (void)addMockFrame:(FIRStackFrame *)frame atAddress:(uint64_t)address {
  [_frames setObject:frame forKey:@(address)];
}

- (BOOL)updateStackFrame:(FIRStackFrame *)frame {
  FIRStackFrame *matchedFrame = [_frames objectForKey:@(frame.address)];

  if (!matchedFrame) {
    return NO;
  }

  [frame setSymbol:matchedFrame.symbol];
  [frame setLibrary:matchedFrame.library];
  [frame setOffset:matchedFrame.offset];

  return YES;
}

- (BOOL)loadBinaryImagesFromFile:(NSString *)path {
  // the mock doesn't need this
  return YES;
}

@end
