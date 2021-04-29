/*
 * Copyright 2021 Google LLC
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

#import "FirebaseAppCheck/Sources/AppAttestProvider/Storage/FIRAppAttestArtifactStorage.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

@implementation FIRAppAttestArtifactStorage

- (nonnull FBLPromise<NSData *> *)getArtifact {
  // TODO: Implement.
  return [FBLPromise resolvedWith:nil];
}

- (nonnull FBLPromise<NSData *> *)setArtifact:(nonnull NSData *)artifact {
  // TODO: Implement.
  return [FBLPromise resolvedWith:nil];
}

@end
