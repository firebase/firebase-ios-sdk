// Copyright 2020 Google LLC
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

#import <TargetConditionals.h>
#if TARGET_OS_WATCH
#warning "Firebase Firestore does not support watchOS"
#endif

#if TARGET_OS_VISION && FIREBASE_BINARY_FIRESTORE
#error "Firebase Firestore's binary SPM distribution does not support \
visionOS. To enable the source distribution, quit Xcode and open the desired \
project from the command line with the FIREBASE_SOURCE_FIRESTORE environment \
variable: `open --env FIREBASE_SOURCE_FIRESTORE /path/to/project.xcodeproj`. \
To go back to using the binary distribution of Firestore, quit Xcode and open \
Xcode like normal, without the environment variable."
#endif
