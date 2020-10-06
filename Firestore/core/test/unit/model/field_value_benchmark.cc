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

#include "Firestore/core/src/model/field_value.h"

#include <limits>
#include <vector>

#include "Firestore/core/src/util/secure_random.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/types/variant.h"
#include "benchmark/benchmark.h"

namespace firebase {
namespace firestore {
namespace model {
namespace {

using Type = FieldValue::Type;

using testutil::Key;
using util::SecureRandom;

std::string RandomString(SecureRandom* rnd, size_t len) {
  std::string s;
  std::generate_n(std::back_inserter(s), len,
                  [&] { return rnd->Uniform(256); });
  return s;
}

void BM_FieldValueStringCopy(benchmark::State& state) {
  util::SecureRandom rnd;

  auto len = static_cast<size_t>(state.range(0));
  FieldValue str = FieldValue::FromString(RandomString(&rnd, len));

  for (auto _ : state) {
    FieldValue copy = str;
  }
}
BENCHMARK(BM_FieldValueStringCopy)
    ->Arg(1 << 2)
    ->Arg(1 << 3)
    ->Arg(1 << 4)
    ->Arg(1 << 5)
    ->Arg(1 << 6)
    ->Arg(1 << 7)
    ->Arg(1 << 8)
    ->Arg(1 << 9)
    ->Arg(1 << 10)
    ->Arg(1 << 15);

void BM_FieldValueStringHash(benchmark::State& state) {
  util::SecureRandom rnd;

  auto len = static_cast<size_t>(state.range(0));
  FieldValue str = FieldValue::FromString(RandomString(&rnd, len));

  for (auto _ : state) {
    str.Hash();
  }
}
BENCHMARK(BM_FieldValueStringHash)
    ->Arg(1 << 2)
    ->Arg(1 << 3)
    ->Arg(1 << 4)
    ->Arg(1 << 5)
    ->Arg(1 << 6)
    ->Arg(1 << 7)
    ->Arg(1 << 8)
    ->Arg(1 << 9)
    ->Arg(1 << 10);

void BM_FieldValueIntegerFill(benchmark::State& state) {
  std::vector<FieldValue> values;
  for (auto _ : state) {
    values.push_back(FieldValue::FromInteger(42));
  }
}
BENCHMARK(BM_FieldValueIntegerFill);

void BM_FieldValueStringFill(benchmark::State& state) {
  SecureRandom rnd;
  auto len = static_cast<size_t>(state.range(0));
  std::string str = RandomString(&rnd, len);

  std::vector<FieldValue> values;
  for (auto _ : state) {
    values.push_back(FieldValue::FromString(str));
  }
}
BENCHMARK(BM_FieldValueStringFill)
    ->Arg(1 << 2)
    ->Arg(1 << 3)
    ->Arg(1 << 4)
    ->Arg(1 << 5)
    ->Arg(1 << 6)
    ->Arg(1 << 7)
    ->Arg(1 << 8)
    ->Arg(1 << 9)
    ->Arg(1 << 10);

using UserType = absl::variant<int64_t, double, std::string, Timestamp>;
struct FromValueVisitor {
  FieldValue operator()(int64_t value) {
    return FieldValue::FromInteger(value);
  }
  FieldValue operator()(double value) {
    return FieldValue::FromDouble(value);
  }
  FieldValue operator()(std::string value) {
    return FieldValue::FromString(std::move(value));
  }
  FieldValue operator()(const Timestamp& value) {
    return FieldValue::FromTimestamp(value);
  }
};

void BM_FieldValueCreation(benchmark::State& state) {
  const int kValues = 128;
  util::SecureRandom rnd;

  std::vector<UserType> input;
  std::generate_n(std::back_inserter(input), kValues, [&]() -> UserType {
    auto choice = rnd.Uniform(10);
    if (choice < 4) {
      return static_cast<int64_t>(42);
    } else if (choice < 8) {
      return RandomString(&rnd, 16);
    } else if (choice < 9) {
      return static_cast<double>(9000);
    } else {
      return Timestamp(42, 0);
    }
  });

  FromValueVisitor visitor;

  std::vector<FieldValue> values;
  int i = 0;
  for (auto _ : state) {
    values.push_back(absl::visit(visitor, input[i]));

    i = (i + 1) % kValues;
  }
}
BENCHMARK(BM_FieldValueCreation);

}  // namespace
}  // namespace model
}  // namespace firestore
}  // namespace firebase
