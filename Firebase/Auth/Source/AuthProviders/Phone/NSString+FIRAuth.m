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

#import "NSString+FIRAuth.h"

#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@implementation NSString (FIRAuth)

- (void)setFir_authPhoneNumber:(NSString *)phoneNumber {
  objc_setAssociatedObject(self, @selector(fir_authPhoneNumber), phoneNumber,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)fir_authPhoneNumber {
  return objc_getAssociatedObject(self, @selector(fir_authPhoneNumber));
}

@end

NS_ASSUME_NONNULL_END
