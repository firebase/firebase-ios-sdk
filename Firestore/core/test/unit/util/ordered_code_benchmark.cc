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

#include "Firestore/core/src/util/ordered_code.h"
#include "Firestore/core/src/util/secure_random.h"
#include "benchmark/benchmark.h"

using firebase::firestore::util::OrderedCode;
using firebase::firestore::util::SecureRandom;

static void BM_SkipToNextSpecialByte(benchmark::State& state) {
  // Use enough distinct values to confuse the branch predictor
  SecureRandom rnd;
  const int kValues = 8192;
  const int kNumSizes = 128;
  int64_t len = state.range(0);
  int64_t sizes[kNumSizes];
  for (int i = 0; i < kNumSizes; i++) {
    // Make a size that is uniform in range of [arg - arg/4..arg + arg/4].
    sizes[i] = len - len / 4 + rnd.Uniform(static_cast<uint32_t>(len / 2 + 1));
  }

  std::vector<std::string> values(kValues);
  for (int i = 0; i < kValues; ++i) {
    std::string s;
    std::generate_n(std::back_inserter(s), sizes[i % kNumSizes],
                    [&] { return rnd.Uniform(254) + 1; });
    s[s.size() - 1] = static_cast<char>(rnd.OneIn(2) ? 0 : 255);
    values[i] = s;
  }

  int index = 0;
  int64_t total_bytes = 0;
  for (auto _ : state) {
    absl::string_view sp(values[index++ % kValues]);
    const char* p = sp.data();
    const char* q = OrderedCode::TEST_SkipToNextSpecialByte(p, p + sp.size());
    total_bytes += (q - p);
  }
  state.SetBytesProcessed(total_bytes);
}
BENCHMARK(BM_SkipToNextSpecialByte)
    ->Arg(1 << 4)
    ->Arg(1 << 5)
    ->Arg(1 << 6)
    ->Arg(1 << 7)
    ->Arg(1 << 8)
    ->Arg(1 << 9)
    ->Arg(1 << 10)
    ->Arg(1 << 15);
