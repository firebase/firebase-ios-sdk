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

#define _FIRMessaging_VERBOSE_LOGGING 1

// Verbose Logging
#if (_FIRMessaging_VERBOSE_LOGGING)
#define FIRMessaging_DEV_VERBOSE_LOG(...) NSLog(__VA_ARGS__)
#else
#define FIRMessaging_DEV_VERBOSE_LOG(...) do { } while (0)
#endif // FIRMessaging_VERBOSE_LOGGING


// WEAKIFY & STRONGIFY
// Helper macro.
#define _FIRMessaging_WEAKNAME(VAR) VAR ## _weak_

#define FIRMessaging_WEAKIFY(VAR) __weak __typeof__(VAR) _FIRMessaging_WEAKNAME(VAR) = (VAR);

#define FIRMessaging_STRONGIFY(VAR) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong __typeof__(VAR) VAR = _FIRMessaging_WEAKNAME(VAR); \
_Pragma("clang diagnostic pop")


// Type Conversions (used for NSInteger etc)
#ifndef _FIRMessaging_L
#define _FIRMessaging_L(v) (long)(v)
#endif

#ifndef _FIRMessaging_UL
#define _FIRMessaging_UL(v) (unsigned long)(v)
#endif

#endif

// Debug Assert
#ifndef _FIRMessagingDevAssert
// we directly invoke the NSAssert handler so we can pass on the varargs
// (NSAssert doesn't have a macro we can use that takes varargs)
#if !defined(NS_BLOCK_ASSERTIONS)
#define _FIRMessagingDevAssert(condition, ...)                                       \
  do {                                                                      \
    if (!(condition)) {                                                     \
      [[NSAssertionHandler currentHandler]                                  \
          handleFailureInFunction:(NSString *)                              \
                                      [NSString stringWithUTF8String:__PRETTY_FUNCTION__] \
                             file:(NSString *)[NSString stringWithUTF8String:__FILE__]  \
                       lineNumber:__LINE__                                  \
                      description:__VA_ARGS__];                             \
    }                                                                       \
  } while(0)
#else // !defined(NS_BLOCK_ASSERTIONS)
#define _FIRMessagingDevAssert(condition, ...) do { } while (0)
#endif // !defined(NS_BLOCK_ASSERTIONS)

#endif // _FIRMessagingDevAssert

// Invalidates the initializer from which it's called.
#ifndef FIRMessagingInvalidateInitializer
#define FIRMessagingInvalidateInitializer() \
  do { \
    [self class]; /* Avoid warning of dead store to |self|. */ \
    _FIRMessagingDevAssert(NO, @"Invalid initializer."); \
    return nil; \
  } while (0)
#endif
