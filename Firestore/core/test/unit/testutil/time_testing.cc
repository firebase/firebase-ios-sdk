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

#include "Firestore/core/test/unit/testutil/time_testing.h"

#include "Firestore/core/src/util/warnings.h"

SUPPRESS_COMMA_WARNINGS_BEGIN()
#include "absl/time/clock.h"
#include "absl/time/time.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace testutil {

std::chrono::time_point<std::chrono::steady_clock, std::chrono::milliseconds>
Now() {
  return std::chrono::time_point_cast<std::chrono::milliseconds>(
      std::chrono::steady_clock::now());
}

time_point MakeTimePoint(
    int year, int month, int day, int hour, int minute, int second) {
  absl::CivilSecond ct(year, month, day, hour, minute, second);
  absl::Time time = absl::FromCivil(ct, absl::UTCTimeZone());
  return absl::ToChronoTime(time);
}

Timestamp MakeTimestamp(
    int year, int month, int day, int hour, int minute, int second) {
  time_point point = MakeTimePoint(year, month, day, hour, minute, second);
  return Timestamp::FromTimePoint(point);
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
