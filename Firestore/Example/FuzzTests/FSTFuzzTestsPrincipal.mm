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
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

using firebase::firestore::model::DatabaseId;
using firebase::firestore::remote::Serializer;
using firebase::firestore::util::MakeString;

namespace {

// A list of targets to fuzz test. Should be kept in sync with the method
// GetFuzzingTarget().
enum class FuzzingTarget { kNone, kSerializer };

// Directory to which crashing inputs are written. Must include the '/' at the
// end because libFuzzer prepends this path to the crashing input file name.
// We write crashes to the temporary directory that is available to the iOS app.
NSString *kCrashingInputsDirectory = NSTemporaryDirectory();

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

// Retrieves the fuzzing target from the FUZZING_TARGET environment variable.
// Default target is kNone if the environment variable is empty, not set, or
// could not be interpreted. Should be kept in sync with FuzzingTarget.
FuzzingTarget GetFuzzingTarget() {
  char *fuzzing_target_env = std::getenv("FUZZING_TARGET");

  if (fuzzing_target_env == NULL || strlen(fuzzing_target_env) == 0) {
    LOG_WARN("No value provided for FUZZING_TARGET environment variable.");
    return FuzzingTarget::kNone;
  }

  if (strcmp("NONE", fuzzing_target_env) == 0) {
    return FuzzingTarget::kNone;
  }
  if (strcmp("SERIALIZER", fuzzing_target_env) == 0) {
    return FuzzingTarget::kSerializer;
  }
  // Value did not match any target.
  LOG_WARN("Invalid fuzzing target: %s", std::string{fuzzing_target_env});
  return FuzzingTarget::kNone;
}

// Simulates calling the main() function of libFuzzer (FuzzerMain.cpp).
// Uses GetFuzzingTarget() to get the fuzzing target and sets libFuzzer's args
// accordingly.
int RunFuzzTestingMain() {
  // Get the fuzzing target.
  FuzzingTarget fuzzing_target = GetFuzzingTarget();
  // All fuzzing resources.
  NSString *resources_location = @"Firestore_FuzzTests_iOS.xctest/FuzzingResources";
  // The dictionary location for the fuzzing target.
  NSString *dict_location;
  // The corpus location for the fuzzing target.
  NSString *corpus_location;

  // Set the dictionary and corpus locations according to the fuzzing target.
  switch (fuzzing_target) {
    case FuzzingTarget::kSerializer:
      dict_location =
          [resources_location stringByAppendingPathComponent:@"Serializer/serializer.dictionary"];
      corpus_location = @"FuzzTestsCorpus";
      break;

    case FuzzingTarget::kNone:
    default:
      LOG_WARN("Not going to run fuzzing, exiting!");
      return 0;
  }

  // Get dictionary and corpus paths from resources and convert to program arguments.
  NSString *plugins_path = [[NSBundle mainBundle] builtInPlugInsPath];

  NSString *dict_path = [plugins_path stringByAppendingPathComponent:dict_location];
  std::string dict_arg = std::string("-dict=") + MakeString(dict_path);

  NSString *corpus_path = [plugins_path stringByAppendingPathComponent:corpus_location];
  std::string corpus_arg = MakeString(corpus_path);

  // The directory in which libFuzzer writes crashing inputs.
  std::string prefix_arg = std::string("-artifact_prefix=") + MakeString(kCrashingInputsDirectory);

  // Arguments to libFuzzer main() function should be added to this array,
  // e.g., dictionaries, corpus, number of runs, jobs, etc. The FuzzerDriver of
  // libFuzzer expects the non-const argument 'char ***argv' and it does not
  // modify it throughout the method.
  char *program_args[] = {
      const_cast<char *>("RunFuzzTestingMain"),  // First arg is program name.
      const_cast<char *>(prefix_arg.c_str()),    // Crashing inputs directory.
      const_cast<char *>(dict_arg.c_str()),      // Dictionary arg.
      const_cast<char *>(corpus_arg.c_str())     // Corpus must be the last arg.
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
