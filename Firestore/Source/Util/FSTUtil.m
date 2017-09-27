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

#import "FSTUtil.h"

NS_ASSUME_NONNULL_BEGIN

static const double kArc4RandomMax = 0x100000000;

static const int kAutoIDLength = 20;
static NSString *const kAutoIDAlphabet =
    @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

@implementation FSTUtil

+ (double)randomDouble {
  return ((double)arc4random() / kArc4RandomMax);
}

+ (NSString *)autoID {
  unichar autoID[kAutoIDLength];
  for (int i = 0; i < kAutoIDLength; i++) {
    uint32_t randIndex = arc4random_uniform((uint32_t)kAutoIDAlphabet.length);
    autoID[i] = [kAutoIDAlphabet characterAtIndex:randIndex];
  }
  return [NSString stringWithCharacters:autoID length:kAutoIDLength];
}

@end

NS_ASSUME_NONNULL_END
