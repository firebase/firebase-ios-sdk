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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_OBJC_CLASS_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_OBJC_CLASS_H_

// The OBJC_CLASS macro defines a forward declaration for an Objective-C class
// that's compatible both with Objective-C++ and regular C++. It's useful in
// headers that reference Objective-C types as members of C++ classes that must
// be usable from straight C++.
//
// Care must be taken to not use the forward declaration (even implicitly) in
// any inline definitions in the header. Even though Objective-C object
// pointers look like raw pointers, under ARC they're more like
// std::shared_ptr, where assignments and copies all potentially change the
// refcount of the pointee. When methods that affect the reference count are
// compiled inline in regular C++ this additional behavior won't get compiled
// in and the Objective-C reference counts will be off.
//
// Note that this may even appear to work, though it does so through undefined
// behavior: inline definitions are deduplicated at link time, and if the
// linker happens to choose a definition that was generated in an ARC-enabled
// translation unit then that specific build will work.
//
// Concretely this means that any method manipulating an Objective-C object
// pointer (constructors, destructors, getters, and setters) all must be
// defined out of line to avoid problems where ARC does not see changes to the
// reference.
#if __OBJC__
#define OBJC_CLASS(name) @class name

#else
#define OBJC_CLASS(name) using name = struct objc_object

#endif  // __OBJC__

// Define NS_ASSUME_NONNULL_BEGIN for straight C++ so that everything gets the
// correct nullability specifier.
#if !defined(NS_ASSUME_NONNULL_BEGIN)
#if __clang__
#define NS_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#define NS_ASSUME_NONNULL_END   _Pragma("clang assume_nonnull end")

#else
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#endif  // __clang__
#endif  // !defined(NS_ASSUME_NONNULL_BEGIN)

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_OBJC_CLASS_H_
