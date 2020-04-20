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

#include <cstdlib>
#include <string>
#include <unordered_map>
#include <vector>

#include "Firestore/Example/FuzzTests/FuzzingTargets/FSTFuzzTestFieldPath.h"
#include "Firestore/Example/FuzzTests/FuzzingTargets/FSTFuzzTestSerializer.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/string_apple.h"
#include "LibFuzzer/FuzzerDefs.h"
#include "absl/strings/str_join.h"

namespace {

using firebase::firestore::util::MakeString;
namespace fuzzing = firebase::firestore::fuzzing;

// A list of targets to fuzz test. Should be kept in sync with
// GetFuzzingTarget() fuzzing_target_names map object.
enum class FuzzingTarget { kNone, kSerializer, kFieldPath };

// Directory to which crashing inputs are written. Must include the '/' at the
// end because libFuzzer prepends this path to the crashing input file name.
// We write crashes to the temporary directory that is available to the iOS app.
NSString *kCrashingInputsDirectory = NSTemporaryDirectory();

// Retrieves the fuzzing target from the FUZZING_TARGET environment variable.
// Default target is kNone if the environment variable is empty, not set, or
// could not be interpreted. Should be kept in sync with FuzzingTarget.
FuzzingTarget GetFuzzingTarget() {
  std::unordered_map<std::string, FuzzingTarget> fuzzing_target_names;
  fuzzing_target_names["NONE"] = FuzzingTarget::kNone;
  fuzzing_target_names["SERIALIZER"] = FuzzingTarget::kSerializer;
  fuzzing_target_names["FIELDPATH"] = FuzzingTarget::kFieldPath;

  const char *fuzzing_target_env = std::getenv("FUZZING_TARGET");

  if (!fuzzing_target_env) {
    LOG_WARN("No value provided for FUZZING_TARGET environment variable.");
    return FuzzingTarget::kNone;
  }

  // Convert fuzzing_target_env to std::string after verifying it is not null.
  std::string fuzzing_target{fuzzing_target_env};
  if (fuzzing_target.empty()) {
    LOG_WARN("No value provided for FUZZING_TARGET environment variable.");
    return FuzzingTarget::kNone;
  }

  // Return the value of the fuzzing_target key if it exists in the
  // fuzzing_target_names map.
  if (fuzzing_target_names.find(fuzzing_target) != fuzzing_target_names.end()) {
    return fuzzing_target_names[fuzzing_target];
  }

  // If the target is not found, print an error message with all available targets.
  // The targets must be enclosed in curly brackets and separated by spaces. This format
  // is needed by the script /firebase-ios-sdk/script/fuzzing_travis.sh, which parses
  // this message to retrieve a list of the available targets.
  std::vector<std::string> all_keys;
  for (const auto &kv : fuzzing_target_names) {
    all_keys.push_back(kv.first);
  }
  const std::string all_keys_str = absl::StrJoin(all_keys, " ");
  LOG_WARN("Invalid fuzzing target: %s. Available targets: { %s }.", fuzzing_target, all_keys_str);
  return FuzzingTarget::kNone;
}

// Retrieves fuzzing duration from the FUZZING_DURATION environment variable.
// Defaults to "0" if the environment variable is empty, which corresponds to
// running indefinitely.
std::string GetFuzzingDuration() {
  const char *fuzzing_duration_env = std::getenv("FUZZING_DURATION");

  if (!fuzzing_duration_env) {
    return "0";
  }

  return std::string{fuzzing_duration_env};
}

// Simulates calling the main() function of libFuzzer (FuzzerMain.cpp).
// Uses GetFuzzingTarget() to get the fuzzing target and sets libFuzzer's args
// accordingly. It also calls an appropriate LLVMFuzzerTestOneInput-like method
// for the defined target.
int RunFuzzTestingMain() {
  // Get the fuzzing target.
  FuzzingTarget fuzzing_target = GetFuzzingTarget();
  // All fuzzing resources.
  std::string resources_location = "Firestore_FuzzTests_iOS.xctest/FuzzingResources";
  // The dictionary location for the fuzzing target.
  std::string dict_location;
  // The corpus location for the fuzzing target.
  std::string corpus_location;

  // Fuzzing target method, equivalent to LLVMFuzzerTestOneInput. Holds a pointer
  // to the fuzzing method that is called repeatedly by the fuzzing driver with
  // different inputs. Any method assigned to this variable must have the same
  // signature as LLVMFuzzerTestOneInput: int(const uint8_t*, size_t).
  fuzzer::UserCallback fuzzer_function;

  // Set the dictionary and corpus locations according to the fuzzing target.
  switch (fuzzing_target) {
    case FuzzingTarget::kSerializer:
      dict_location = fuzzing::GetSerializerDictionaryLocation(resources_location);
      corpus_location = fuzzing::GetSerializerCorpusLocation();
      fuzzer_function = fuzzing::FuzzTestDeserialization;
      break;

    case FuzzingTarget::kFieldPath:
      dict_location = fuzzing::GetFieldPathDictionaryLocation(resources_location);
      corpus_location = fuzzing::GetFieldPathCorpusLocation(resources_location);
      fuzzer_function = fuzzing::FuzzTestFieldPath;
      break;

    case FuzzingTarget::kNone:
    default:
      LOG_WARN("Not going to run fuzzing, exiting!");
      return 0;
  }

  // Get dictionary and corpus paths from resources and convert to program arguments.
  NSString *plugins_path = [[NSBundle mainBundle] builtInPlugInsPath];

  std::string dict_path = MakeString(plugins_path) + "/" + dict_location;
  std::string dict_arg = std::string("-dict=") + dict_path;

  // No argument prefix required for corpus arg.
  std::string corpus_arg = MakeString(plugins_path) + "/" + corpus_location;

  // The directory in which libFuzzer writes crashing inputs.
  std::string prefix_arg = std::string("-artifact_prefix=") + MakeString(kCrashingInputsDirectory);

  // Run fuzzing for the defined fuzzing duration.
  std::string time_arg = "-max_total_time=" + GetFuzzingDuration();

  // Arguments to libFuzzer main() function should be added to this array,
  // e.g., dictionaries, corpus, number of runs, jobs, etc. The FuzzerDriver of
  // libFuzzer expects the non-const argument 'char ***argv' and it does not
  // modify it throughout the method.
  char *program_args[] = {
      const_cast<char *>("RunFuzzTestingMain"),  // First arg is program name.
      const_cast<char *>(prefix_arg.c_str()),    // Crashing inputs directory.
      const_cast<char *>(time_arg.c_str()),      // Maximum total time.
      const_cast<char *>(dict_arg.c_str()),      // Dictionary arg.
      const_cast<char *>(corpus_arg.c_str())     // Corpus must be the last arg.
  };
  char **argv = program_args;
  int argc = sizeof(program_args) / sizeof(program_args[0]);

  // Start fuzzing using libFuzzer's driver.
  return fuzzer::FuzzerDriver(&argc, &argv, fuzzer_function);
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
