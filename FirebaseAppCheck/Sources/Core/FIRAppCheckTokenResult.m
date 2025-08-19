/*
 * Copyright 2020 Google LLC
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

#import "Core/FIRAppCheckTokenResult.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRAppCheckTokenResult

@synthesize token = _token;
@synthesize error = _error;

- (instancetype)initWithToken:(NSString *)token error:(nullable NSError *)error {
  self = [super init];
  if (self) {
    _token = token;
    _error = error;
  }
  return self;
}

@end

NS_ASSUME_NONNULL_END
