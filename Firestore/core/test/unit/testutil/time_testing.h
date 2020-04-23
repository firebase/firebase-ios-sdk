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

#ifndef FIRESTORE_CORE_TEST_UNIT_TESTUTIL_TIME_TESTING_H_
#define FIRESTORE_CORE_TEST_UNIT_TESTUTIL_TIME_TESTING_H_

#include <chrono>  // NOLINT(build/c++11)

#include "Firestore/core/include/firebase/firestore/timestamp.h"

namespace firebase {
namespace firestore {
namespace testutil {

using time_point = std::chrono::system_clock::time_point;

/** Returns the current time, in milliseconds. */
std::chrono::time_point<std::chrono::steady_clock, std::chrono::milliseconds>
Now();

/**
 * Makes a TimePoint from the given date components, given in UTC.
 */
time_point MakeTimePoint(
    int year, int month, int day, int hour, int minute, int second);

Timestamp MakeTimestamp(
    int year, int month, int day, int hour, int minute, int second);

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_TESTUTIL_TIME_TESTING_H_
