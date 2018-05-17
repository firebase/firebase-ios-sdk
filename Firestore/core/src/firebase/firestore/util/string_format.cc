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

#include "Firestore/core/src/firebase/firestore/util/string_format.h"

namespace firebase {
namespace firestore {
namespace util {
namespace internal {

static const char* kMissing = "<missing>";
static const char* kInvalid = "<invalid>";

std::string StringFormatPieces(
    const char* format, std::initializer_list<absl::string_view> pieces) {
  std::string result;

  const char* format_iter = format;
  const char* format_end = format + strlen(format);
  auto pieces_iter = pieces.begin();
  auto pieces_end = pieces.end();

  while (true) {
    const char* percent_ptr = std::find(format_iter, format_end, '%');

    // percent either points to the next format specifier or the end of the
    // format string. Either is safe to append here:
    result.append(format_iter, percent_ptr - format_iter);

    if (percent_ptr == format_end) {
      // No further pieces to format
      break;
    }

    // Examine the specifier:
    const char* spec_ptr = percent_ptr + 1;
    if (spec_ptr == format_end) {
      // Incomplete specifier, treat as a literal "%" and be done.
      result.append("%", 1);
      break;
    }

    char spec = *spec_ptr;
    switch (spec) {
      case '%':
        // Pass through literal %.
        result.append(spec_ptr, 1);
        break;

      case 's':
        if (pieces_iter == pieces_end) {
          result.append(kMissing);
        } else {
          // Pass a piece through
          result.append(pieces_iter->data(), pieces_iter->size());
          ++pieces_iter;
        }
        break;

      default:
        result.append(kInvalid);
        break;
    }

    format_iter = spec_ptr + 1;
  }

  return result;
}

}  // namespace internal
}  // namespace util
}  // namespace firestore
}  // namespace firebase
