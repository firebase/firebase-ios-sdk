/*
 * Copyright 2017 Google
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

#import "FIRSetOptions+Internal.h"
#import "FSTMutation.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRSetOptions

- (instancetype)initWithMerge:(BOOL)merge {
  if (self = [super init]) {
    _merge = merge;
  }
  return self;
}

+ (instancetype)merge {
  return [[FIRSetOptions alloc] initWithMerge:YES];
}

- (BOOL)isEqual:(id)other {
  if (self == other) {
    return YES;
  } else if (![other isKindOfClass:[FIRSetOptions class]]) {
    return NO;
  }

  FIRSetOptions *otherOptions = (FIRSetOptions *)other;

  return otherOptions.merge != self.merge;
}

- (NSUInteger)hash {
  return self.merge ? 1231 : 1237;
}
@end

@implementation FIRSetOptions (Internal)

+ (instancetype)overwrite {
  static FIRSetOptions *overwriteInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    overwriteInstance = [[FIRSetOptions alloc] initWithMerge:NO];
  });
  return overwriteInstance;
}

@end

NS_ASSUME_NONNULL_END
