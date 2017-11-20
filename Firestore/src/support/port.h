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

#ifndef FIRESTORE_SRC_SUPPORT_PORT_H_
#define FIRESTORE_SRC_SUPPORT_PORT_H_

#if defined(__APPLE__)
// On Apple platforms we support building via Cocoapods without CMake. When
// building this way we can't test the presence of features so predefine all
// the platform-support feature macros to their expected values.

// All supported Apple platforms have arc4random(3).
#define HAVE_ARC4RANDOM 1

#else

#error "Unknown platform."
#endif  // defined(__APPLE__)

#endif  // FIRESTORE_SRC_SUPPORT_PORT_H_
