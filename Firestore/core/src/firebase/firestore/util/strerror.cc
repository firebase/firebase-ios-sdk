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

// Implementation note:
//
// This is ported from //base/strerror.cc, with several local modifications:
//
//   * Removed non-portable optimization around to use sys_errlist where
//     available without warnings.
//   * Added __attribute__((unused)) to compile with -Wno-unused-functions.
//   * Conformed to style/lint rules.

#include "Firestore/core/src/firebase/firestore/util/strerror.h"

#include <cerrno>
#include <cstdio>
#if defined(_WIN32)
#include <cstring>
#endif

namespace firebase {
namespace firestore {
namespace util {

namespace {

#if !defined(_WIN32)
#if defined(__GNUC__)
#define POSSIBLY_UNUSED __attribute__((unused))
#else
#define POSSIBLY_UNUSED
#endif

// Only one of these overloads will be used in any given build, as determined by
// the return type of strerror_r(): char* (for GNU), or int (for XSI).  See 'man
// strerror_r' for more details.
POSSIBLY_UNUSED const char* StrErrorR(char* (*strerror_r)(int, char*, size_t),
                                      int errnum,
                                      char* buf,
                                      size_t buflen) {
  return strerror_r(errnum, buf, buflen);
}

POSSIBLY_UNUSED const char* StrErrorR(int (*strerror_r)(int, char*, size_t),
                                      int errnum,
                                      char* buf,
                                      size_t buflen) {
  if (strerror_r(errnum, buf, buflen)) {
    *buf = '\0';
  }
  return buf;
}
#endif  // !defined(_WIN32)

inline const char* StrErrorAdaptor(int errnum, char* buf, size_t buflen) {
#if defined(_WIN32)
  int rc = strerror_s(buf, buflen, errnum);
  buf[buflen - 1] = '\0';  // guarantee NUL termination

  if (rc == 0 && strcmp(buf, "Unknown error") == 0) {
    *buf = '\0';
  }
  return buf;

#elif defined(__GLIBC__) || defined(__APPLE__)
  return StrErrorR(strerror_r, errnum, buf, buflen);
#endif  // defined(_WIN32)
}

}  // namespace

std::string StrError(int errnum) {
  const int saved_errno = errno;

  char buf[100];
  const char* str = StrErrorAdaptor(errnum, buf, sizeof buf);
  if (*str == '\0') {
    snprintf(buf, sizeof buf, "Unknown error %d", errnum);
    str = buf;
  }

  errno = saved_errno;
  return str;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
