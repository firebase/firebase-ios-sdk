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

#include "Firestore/core/src/util/json_reader.h"

#include "Firestore/core/src/util/no_destructor.h"
#include "Firestore/core/src/util/string_util.h"

namespace firebase {
namespace firestore {
namespace util {

using nlohmann::json;
using util::NoDestructor;

namespace {

template <typename T>
const std::vector<T>& EmptyVector() {
  static NoDestructor<std::vector<T>> empty;
  return *empty;
}

}  // namespace

const std::string& JsonReader::RequiredString(const char* name,
                                              const json& json_object) {
  if (json_object.contains(name)) {
    const json& child = json_object.at(name);
    if (child.is_string()) {
      return child.get_ref<const std::string&>();
    }
  }

  Fail("'%s' is missing or is not a string", name);
  return util::EmptyString();
}

const std::string& JsonReader::OptionalString(
    const char* name,
    const json& json_object,
    const std::string& default_value) {
  if (json_object.contains(name)) {
    const json& child = json_object.at(name);
    if (child.is_string()) {
      return child.get_ref<const std::string&>();
    }
  }

  return default_value;
}

const std::vector<json>& JsonReader::RequiredArray(const char* name,
                                                   const json& json_object) {
  if (json_object.contains(name)) {
    const json& child = json_object.at(name);
    if (child.is_array()) {
      return child.get_ref<const std::vector<json>&>();
    }
  }

  Fail("'%s' is missing or is not an array", name);
  return EmptyVector<json>();
}

const std::vector<json>& JsonReader::OptionalArray(
    const char* name,
    const json& json_object,
    const std::vector<json>& default_value) {
  if (!json_object.contains(name)) {
    return default_value;
  }

  const json& child = json_object.at(name);
  if (child.is_array()) {
    return child.get_ref<const std::vector<json>&>();
  } else {
    Fail("'%s' is not an array", name);
    return EmptyVector<json>();
  }
}

bool JsonReader::OptionalBool(const char* name,
                              const json& json_object,
                              bool default_value) {
  return (json_object.contains(name) && json_object.at(name).is_boolean() &&
          json_object.at(name).get<bool>()) ||
         default_value;
}

const nlohmann::json& JsonReader::RequiredObject(const char* child_name,
                                                 const json& json_object) {
  if (!json_object.contains(child_name)) {
    Fail("Missing child '%s'", child_name);
    return json_object;
  }
  return json_object.at(child_name);
}

const nlohmann::json& JsonReader::OptionalObject(
    const char* child_name,
    const json& json_object,
    const nlohmann::json& default_value) {
  if (json_object.contains(child_name)) {
    return json_object.at(child_name);
  }
  return default_value;
}

double JsonReader::RequiredDouble(const char* name, const json& json_object) {
  if (json_object.contains(name)) {
    double result = DecodeDouble(json_object.at(name));
    if (ok()) {
      return result;
    }
  }

  Fail("'%s' is missing or is not a double", name);
  return 0.0;
}

double JsonReader::OptionalDouble(const char* name,
                                  const json& json_object,
                                  double default_value) {
  if (json_object.contains(name)) {
    double result = DecodeDouble(json_object.at(name));
    if (ok()) {
      return result;
    }
  }

  return default_value;
}

double JsonReader::DecodeDouble(const nlohmann::json& value) {
  if (value.is_number()) {
    return value.get<double>();
  }

  double result = 0;
  if (value.is_string()) {
    const auto& s = value.get_ref<const std::string&>();
    auto ok = absl::SimpleAtod(s, &result);
    if (!ok) {
      Fail("Failed to parse into double: " + s);
    }
  }
  return result;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
