/*
 * Copyright 2022 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_UTIL_JSON_READER_H_
#define FIRESTORE_CORE_SRC_UTIL_JSON_READER_H_

#include <string>
#include <vector>

#include "Firestore/core/src/util/read_context.h"
#include "Firestore/third_party/nlohmann_json/json.hpp"

namespace firebase {
namespace firestore {
namespace util {

/**
 * Provides the ability to report failure cases by inheriting `ReadContext`, and
 * checks and reads json object into specified types.
 *
 * `Required*` methods check the existence of the given name and compatibility
 * of its value (can it be read into the given type?). They fail the reader if
 * any of the checks fail, otherwise return the read value.
 *
 * `Optional*` methods check the existence of the given name, and return a
 * specified default value if the name does not exist. They then check
 * compatibility of its value, fail the reader if that check fails, or return
 * the read value if it succeeds.
 */
class JsonReader : public util::ReadContext {
 public:
  const std::string& RequiredString(const char* name,
                                    const nlohmann::json& json_object);
  const std::string& OptionalString(const char* name,
                                    const nlohmann::json& json_object,
                                    const std::string& default_value);

  const std::vector<nlohmann::json>& RequiredArray(
      const char* name, const nlohmann::json& json_object);
  const std::vector<nlohmann::json>& OptionalArray(
      const char* name,
      const nlohmann::json& json_object,
      const std::vector<nlohmann::json>& default_value);

  const nlohmann::json& RequiredObject(const char* child_name,
                                       const nlohmann::json& json_object);
  const nlohmann::json& OptionalObject(const char* child_name,
                                       const nlohmann::json& json_object,
                                       const nlohmann::json& default_value);

  double RequiredDouble(const char* name, const nlohmann::json& json_object);
  double OptionalDouble(const char* name,
                        const nlohmann::json& json_object,
                        double default_value = 0);

  template <typename IntType>
  IntType RequiredInt(const char* name, const nlohmann::json& json_object) {
    if (!json_object.contains(name)) {
      Fail("'%s' is missing or is not a double", name);
      return 0;
    }

    const nlohmann::json& value = json_object.at(name);
    return ParseInt<IntType>(value, *this);
  }

  template <typename IntType>
  IntType OptionalInt(const char* name,
                      const nlohmann::json& json_object,
                      IntType default_value) {
    if (!json_object.contains(name)) {
      return default_value;
    }

    const nlohmann::json& value = json_object.at(name);
    return ParseInt<IntType>(value, *this);
  }

  static bool OptionalBool(const char* name,
                           const nlohmann::json& json_object,
                           bool default_value = false);

 private:
  double DecodeDouble(const nlohmann::json& value);

  template <typename IntType>
  IntType ParseInt(const nlohmann::json& value, JsonReader& reader) {
    if (value.is_number_integer()) {
      return value.get<IntType>();
    }

    IntType result = 0;
    if (value.is_string()) {
      const auto& s = value.get_ref<const std::string&>();
      auto ok = absl::SimpleAtoi<IntType>(s, &result);
      if (!ok) {
        reader.Fail("Failed to parse into integer: " + s);
        return 0;
      }

      return result;
    }

    reader.Fail("Only integer and string can be parsed into int type");
    return 0;
  }
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_JSON_READER_H_
