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

#include "Firestore/core/test/firebase/firestore/testutil/time_testing.h"

#include <utility>

namespace firebase {
namespace firestore {
namespace testutil {

#if defined(_WIN32)
#define timegm _mkgmtime

#elif defined(__ANDROID__)
// time.h doesn't necessarily define this properly, even though it's present
// from API 12 and up.
extern time_t timegm(struct tm*);
#endif

time_point MakeTimePoint(
    int year, int month, int day, int hour, int minute, int second) {
  struct std::tm tm {};
  tm.tm_year = year - 1900;  // counts from 1900
  tm.tm_mon = month - 1;     // counts from 0
  tm.tm_mday = day;          // counts from 1
  tm.tm_hour = hour;
  tm.tm_min = minute;
  tm.tm_sec = second;

  // std::mktime produces a time value in local time, and conversion to GMT is
  // not defined. timegm is nonstandard but widespread enough for our purposes.
  time_t t = timegm(&tm);
  return time_point::clock::from_time_t(t);
}

Timestamp MakeTimestamp(
    int year, int month, int day, int hour, int minute, int second) {
  time_point point = MakeTimePoint(year, month, day, hour, minute, second);
  return Timestamp::FromTimePoint(point);
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
