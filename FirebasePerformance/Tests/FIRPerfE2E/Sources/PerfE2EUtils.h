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

#import <UIKit/UIKit.h>

/**
 * Generate a random value following Gaussian distribution using the mean and the deviation values
 * provided. This uses the Box-Mueller transform to implement the distribution.
 * Reference: https://en.wikipedia.org/wiki/Box%E2%80%93Muller_transform
 *
 * @param mean Mean value to be used for the random number generation.
 * @param deviation Deviation from the mean value that is acceptable.
 * @return The random value that obeys the Gaussian distribution.
 */
extern CGFloat randomGaussianValueWithMeanAndDeviation(CGFloat mean, CGFloat deviation);
