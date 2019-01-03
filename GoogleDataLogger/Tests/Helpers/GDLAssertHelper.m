/*
 * Copyright 2018 Google
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

#import "GDLAssertHelper.h"

@implementation GDLAssertHelper

// The backing store for the class variable assertionBlock.
static GDLAssertionBlock gSharedAssertionBlock;

+ (GDLAssertionBlock)assertionBlock {
  return gSharedAssertionBlock;
}

+ (void)setAssertionBlock:(GDLAssertionBlock)assertionBlock {
  gSharedAssertionBlock = assertionBlock;
}

@end
