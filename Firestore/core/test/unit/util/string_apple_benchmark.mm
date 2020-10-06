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

#include "Firestore/core/src/util/string_apple.h"

#include <string>

#include "benchmark/benchmark.h"

using firebase::firestore::util::MakeString;
using firebase::firestore::util::MakeStringView;

static void BM_MakeString(benchmark::State& state) {
  NSString* source = [NSString stringWithCString:"hello world"
                                        encoding:NSUTF8StringEncoding];
  for (auto _ : state) {
    std::string actual = MakeString(source);
    (void)actual;
  }
}
BENCHMARK(BM_MakeString);

static void BM_MakeStringView(benchmark::State& state) {
  NSString* source = [NSString stringWithCString:"hello world"
                                        encoding:NSUTF8StringEncoding];
  for (auto _ : state) {
    absl::string_view actual = MakeStringView(source);
    (void)actual;
  }
}
BENCHMARK(BM_MakeStringView);
