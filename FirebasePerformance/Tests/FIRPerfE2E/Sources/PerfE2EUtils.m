// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "PerfE2EUtils.h"

CGFloat randomGaussianValueWithMeanAndDeviation(CGFloat mean, CGFloat deviation) {
  CGFloat randomValue1 = ((double)arc4random_uniform(UINT32_MAX)) / (double)UINT32_MAX;
  CGFloat randomValue2 = ((double)arc4random_uniform(UINT32_MAX)) / (double)UINT32_MAX;
  CGFloat gaussianValue = sqrt(-2 * log(randomValue1)) * cos(2 * M_PI * randomValue2);
  CGFloat returnValue = mean + (deviation * gaussianValue);
  return returnValue;
}
