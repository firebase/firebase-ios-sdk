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

#include "Firestore/core/src/util/string_win.h"

#include <ios>

#include "absl/strings/string_view.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

#if defined(_WIN32)

TEST(StringWindowsTest, Empty) {
  EXPECT_EQ(std::wstring{L""}, Utf8ToNative(""));
  EXPECT_EQ(std::string{""}, NativeToUtf8(L""));
}

TEST(StringWindowsTest, EmbeddedNulls) {
  std::string embedded_nulls({'\0', ' ', 'a'}, 3);
  std::wstring wembedded_nulls({L'\0', L' ', L'a'}, 3);
  EXPECT_EQ(wembedded_nulls, Utf8ToNative(embedded_nulls));
  EXPECT_EQ(embedded_nulls, NativeToUtf8(wembedded_nulls));
}

TEST(StringWindowsTest, NonAscii) {
  // left and right curly quotation marks
  std::string curly{u8"\u2018hi\u2019"};
  std::wstring wcurly{L"\u2018hi\u2019"};
  EXPECT_EQ(wcurly, Utf8ToNative(curly));
  EXPECT_EQ(curly, NativeToUtf8(wcurly));
}

TEST(StringWindowsTest, InvalidUtf8) {
  // The 0xFF byte is not valid in UTF-8; Windows will replace with U+FFFD
  // (replacement character)
  std::string invalid{"\xff\xff"};
  std::wstring winvalid_replaced{L"\ufffd\ufffd"};
  EXPECT_EQ(winvalid_replaced, Utf8ToNative(invalid));

  // Missing the trailing part of the surrogate pair. MSVC seemingly won't allow
  // surrogates to appear in a string literal (complete or otherwise).
  std::wstring winvalid(L"AA");
  winvalid[1] = static_cast<wchar_t>(0xD800);
  std::string invalid_replacement{u8"A\ufffd"};
  EXPECT_EQ(invalid_replacement, NativeToUtf8(winvalid));
}

/**
 * Temporarily sets the current language for the current thread to the given
 * language. Restores the previously current language when the instance is
 * destructed.
 */
class TemporaryLanguage {
 public:
  explicit TemporaryLanguage(LANGID lang_id) {
    previous_lang_id_ = ::GetThreadUILanguage();
    LANGID result = ::SetThreadUILanguage(lang_id);
    if (result != lang_id) {
      DWORD error = ::GetLastError();
      ADD_FAILURE() << "SetThreadUILanguage(" << std::hex << lang_id
                    << ") failed with error " << std::dec << error;
    }
  }

  ~TemporaryLanguage() {
    ::SetThreadUILanguage(previous_lang_id_);
  }

 private:
  LANGID previous_lang_id_;
};

TEST(StringWindowsTest, LastErrorMessage) {
  TemporaryLanguage lang{MAKELANGID(LANG_ENGLISH, SUBLANG_ENGLISH_US)};

  EXPECT_EQ(std::string{"The parameter is incorrect."},
            LastErrorMessage(ERROR_INVALID_PARAMETER));
}

#endif  // defined(_WIN32)

}  //  namespace util
}  //  namespace firestore
}  //  namespace firebase
