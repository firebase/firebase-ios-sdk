/*
 * Copyright 2020 Google LLC
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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "benchmark/benchmark.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * An adapter for Google Benchmark that allows it to run as if it's an XCTest
 * test case. This makes it possible to easily run those benchmarks on an iPhone
 * directly from within Xcode.
 */
@interface FSTBenchmarkTests : XCTestCase
@end

@implementation FSTBenchmarkTests

- (void)testRunBenchmarks {
  char* argv[] = {
      const_cast<char*>("FSTBenchmarkTests"),
      const_cast<char*>("--benchmark_filter=BM_.*"),
  };
  int argc = sizeof(argv) / sizeof(argv[0]);
  benchmark::Initialize(&argc, argv);
  benchmark::RunSpecifiedBenchmarks();
}

@end

NS_ASSUME_NONNULL_END
