//
// Copyright 2022 Google LLC
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

#ifndef FirebaseSessionsInternal_h
#define FirebaseSessionsInternal_h

#import <Foundation/Foundation.h>

// This header is necessary for including the Interop header
// in the Swift part of the codebase under Swift Package Manager
// TODO(b/264274170) Remove the interop and make the dependency direct
#import "FirebaseSessions/Internal/FIRSessionsProvider.h"

NS_ASSUME_NONNULL_BEGIN

NS_ASSUME_NONNULL_END

#endif /* FirebaseSessionsInternal_h */
