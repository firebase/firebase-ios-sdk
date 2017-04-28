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

#ifndef FIREBASECORE_CORE_FIRSWIFTNAMESUPPORT_H_
#define FIREBASECORE_CORE_FIRSWIFTNAMESUPPORT_H_

// In Xcode 7.0-7.2, NS_SWIFT_NAME can only translate factory methods. In order to keep
// compatibility we will undefine it when linking against earlier iPhone SDKs and redefine it as an
// empty string. Xcode 7.3 shipped with the iOS 9.3 SDK, so if __IPHONE_9_3 is defined no action is
// necessary.
#ifndef __IPHONE_9_3
#ifdef NS_SWIFT_NAME
#undef NS_SWIFT_NAME
#endif  // #ifdef NS_SWIFT_NAME
#define NS_SWIFT_NAME(_)  // Intentionally blank.
#endif  // #ifndef __IPHONE_9_3

#endif  // FIREBASECORE_CORE_FIRSWIFTNAMESUPPORT_H_
