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

#import <Foundation/NSObject.h>

#include "LibFuzzer/FuzzerDefs.h"

#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"

using firebase::firestore::model::DatabaseId;
using firebase::firestore::remote::Serializer;

namespace {

// Fuzz-test the deserialization process in Firestore. The Serializer reads raw
// bytes and converts them to a model object.
void FuzzTestDeserialization(const uint8_t *data, size_t size) {
  Serializer serializer{DatabaseId{"project", DatabaseId::kDefault}};

  @autoreleasepool {
    @try {
      serializer.DecodeFieldValue(data, size);
    } @catch (...) {
      // Caught exceptions are ignored because the input might be malformed and
      // the deserialization might throw an error as intended. Fuzzing focuses on
      // runtime errors that are detected by the sanitizers.
    }
  }
}

// Contains the code to be fuzzed. Called by the fuzzing library with
// different argument values for `data` and `size`.
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  FuzzTestDeserialization(data, size);
  return 0;
}

// Simulates calling the main() function of libFuzzer (FuzzerMain.cpp).
int RunFuzzTestingMain() {
  // Get dictionary file path from resources and convert to a program argument.
  NSString *plugins_path = [[NSBundle mainBundle] builtInPlugInsPath];

  NSString *dict_location =
      @"Firestore_FuzzTests_iOS.xctest/FuzzingResources/Serializer/serializer.dictionary";
  NSString *dict_path = [plugins_path stringByAppendingPathComponent:dict_location];
  const char *dict_arg = [[NSString stringWithFormat:@"-dict=%@", dict_path] UTF8String];

  // Get corpus and convert to a program argument.
  NSString *corpus_location = @"FuzzTestsCorpus";
  NSString *corpus_path = [plugins_path stringByAppendingPathComponent:corpus_location];
  const char *corpus_arg = [corpus_path UTF8String];

  // Arguments to libFuzzer main() function should be added to this array,
  // e.g., dictionaries, corpus, number of runs, jobs, etc. The FuzzerDriver of
  // libFuzzer expects the non-const argument 'char ***argv' and it does not
  // modify it throughout the method.
  char *program_args[] = {
      const_cast<char *>("RunFuzzTestingMain"),  // First arg is program name.
      const_cast<char *>(dict_arg),              // Dictionary arg.
      const_cast<char *>(corpus_arg)             // Corpus must be the last arg.
  };
  char **argv = program_args;
  int argc = sizeof(program_args) / sizeof(program_args[0]);

  // Start fuzzing using libFuzzer's driver.
  return fuzzer::FuzzerDriver(&argc, &argv, LLVMFuzzerTestOneInput);
}

}  // namespace

/**
 * This class is registered as the NSPrincipalClass in the
 * Firestore_FuzzTests_iOS bundle's Info.plist. XCTest instantiates this class
 * to perform one-time setup for the test bundle, as documented here:
 *
 *   https://developer.apple.com/documentation/xctest/xctestobservationcenter
 */
@interface FSTFuzzTestsPrincipal : NSObject
@end

@implementation FSTFuzzTestsPrincipal

- (instancetype)init {
  self = [super init];
  RunFuzzTestingMain();
  return self;
}

@end
