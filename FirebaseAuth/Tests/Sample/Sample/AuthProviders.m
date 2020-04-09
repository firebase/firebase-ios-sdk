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

#import "AuthProviders.h"

#import "FacebookAuthProvider.h"
#import "GoogleAuthProvider.h"

@implementation AuthProviders

+ (id<AuthProvider>)google {
  static id<AuthProvider> googleAuthProvider;
  if (!googleAuthProvider) {
    googleAuthProvider = [[GoogleAuthProvider alloc] init];
  }
  return googleAuthProvider;
}

+ (id<AuthProvider>)facebook {
  static id<AuthProvider> facebookAuthProvider;
  if (!facebookAuthProvider) {
    facebookAuthProvider = [[FacebookAuthProvider alloc] init];
  }
  return facebookAuthProvider;
}

@end
