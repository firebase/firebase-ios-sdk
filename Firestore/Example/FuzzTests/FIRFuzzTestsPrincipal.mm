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

#import <Foundation/Foundation.h>

#include "FuzzerDefs.h"

namespace {

  // Contains the code to be fuzzed. Called by the fuzzing library with
  // different argument values for `data` and `size`.
  int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    // Code to be fuzz-tested here.
    return 0;
  }

  // Simulates calling the main() function of libFuzzer (FuzzerMain.cpp).
  int RunFuzzTestingMain() {
    // Arguments to libFuzzer main() function should be added to this array,
    // e.g., dictionaries, corpus, number of runs, jobs, etc.
    // Arguments are casted as character arrays because C++11 does not allow
    // the conversion from string literals to character arrays.
    char *programArgs[] = {
      (char *) "RunFuzzTestingMain"  // First argument is program name.
    };
    char **argv = programArgs;
    int argc = sizeof(programArgs)/sizeof(programArgs[0]);

    // Start fuzzing using libFuzzer's driver.
    return fuzzer::FuzzerDriver(&argc, &argv, LLVMFuzzerTestOneInput);
  }

}  // namespace

/**
 * This class is registered as the NSPrincipalClass in the
 * Firestore_FuzzTests_iOS bundle's Info.plist. XCTest instantiates this class
 * to perform one-time setup
 * for the test bundle, as documented here:
 *
 *   https://developer.apple.com/documentation/xctest/xctestobservationcenter
 */
@interface FIRFuzzTestsPrincipal : NSObject
@end

@implementation FIRFuzzTestsPrincipal

- (instancetype) init {
  self = [super init];
  RunFuzzTestingMain();
  return self;
}

@end
