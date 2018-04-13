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

#include "Firestore/core/src/firebase/firestore/util/string_printf.h"

#include <cstdio>

namespace firebase {
namespace firestore {
namespace util {

void StringAppendV(std::string* dst, const char* format, va_list ap) {
  // First try with a small fixed size buffer
  static const int kSpaceLength = 1024;
  char space[kSpaceLength];

  // It's possible for methods that use a va_list to invalidate
  // the data in it upon use.  The fix is to make a copy
  // of the structure before using it and use that copy instead.
  va_list backup_ap;
  va_copy(backup_ap, ap);
  int result = vsnprintf(space, kSpaceLength, format, backup_ap);
  va_end(backup_ap);

  if (result < kSpaceLength) {
    if (result >= 0) {
      // Normal case -- everything fit.
      dst->append(space, static_cast<size_t>(result));
      return;
    }

#ifdef _MSC_VER
    // Error or MSVC running out of space.  MSVC 8.0 and higher
    // can be asked about space needed with the special idiom below:
    va_copy(backup_ap, ap);
    result = vsnprintf(nullptr, 0, format, backup_ap);
    va_end(backup_ap);
#endif
  }

  if (result < 0) {
    // Just an error.
    return;
  }
  size_t result_size = static_cast<size_t>(result);

  // Increase the buffer size to the size requested by vsnprintf,
  // plus one for the closing \0.
  size_t initial_size = dst->size();
  size_t target_size = initial_size + result_size;

  dst->resize(target_size + 1);
  char* buf = &(*dst)[initial_size];
  size_t buf_remain = result_size + 1;

  // Restore the va_list before we use it again
  va_copy(backup_ap, ap);
  result = vsnprintf(buf, buf_remain, format, backup_ap);
  va_end(backup_ap);

  if (result >= 0 && static_cast<size_t>(result) < buf_remain) {
    // It fit and vsnprintf copied in directly. Resize down one to
    // remove the trailing \0.
    dst->resize(target_size);
  } else {
    // Didn't fit. Leave the original string unchanged.
    dst->resize(initial_size);
  }
}

std::string StringPrintf(const char* format, ...) {
  va_list ap;
  va_start(ap, format);
  std::string result;
  StringAppendV(&result, format, ap);
  va_end(ap);
  return result;
}

void StringAppendF(std::string* dst, const char* format, ...) {
  va_list ap;
  va_start(ap, format);
  StringAppendV(dst, format, ap);
  va_end(ap);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
