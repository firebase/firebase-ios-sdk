/*
 * Copyright 2019 Google
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

#import "FirebaseAppDistribution/Sources/FIRAppDistributionMachOSlice.h"
#import <mach-o/fat.h>
#import <mach-o/loader.h>

NS_ASSUME_NONNULL_BEGIN

@implementation FIRAppDistributionMachOSlice

- (instancetype)initWithArch:(const NXArchInfo *)arch uuid:(NSUUID *)uuid {
  self = [super init];
  if (!self) return nil;

  _arch = arch;
  _uuid = uuid;
  return self;
}

- (NSString *)architectureName {
  return [NSString stringWithUTF8String:_arch->name];
}

- (NSString *)uuidString {
  return [[[_uuid UUIDString] lowercaseString] stringByReplacingOccurrencesOfString:@"-"
                                                                         withString:@""];
}
@end

NS_ASSUME_NONNULL_END
