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

#ifndef FIRMessaging_xcodeproj_FIRMessagingDefines_h
#define FIRMessaging_xcodeproj_FIRMessagingDefines_h

// WEAKIFY & STRONGIFY
// Helper macro.
#define _FIRMessaging_WEAKNAME(VAR) VAR ## _weak_

#define FIRMessaging_WEAKIFY(VAR) __weak __typeof__(VAR) _FIRMessaging_WEAKNAME(VAR) = (VAR);

#define FIRMessaging_STRONGIFY(VAR) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong __typeof__(VAR) VAR = _FIRMessaging_WEAKNAME(VAR); \
_Pragma("clang diagnostic pop")


#ifndef _FIRMessaging_UL
#define _FIRMessaging_UL(v) (unsigned long)(v)
#endif

#endif

// Invalidates the initializer from which it's called.
#ifndef FIRMessagingInvalidateInitializer
#define FIRMessagingInvalidateInitializer() \
  do { \
    [self class]; /* Avoid warning of dead store to |self|. */ \
    NSAssert(NO, @"Invalid initializer."); \
    return nil; \
  } while (0)
#endif
