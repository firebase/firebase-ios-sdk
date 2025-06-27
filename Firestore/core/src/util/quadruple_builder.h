//  Copyright 2025 Google LLC
//  Copyright 2021 M.Vokhmentsev
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#ifndef FIRESTORE_CORE_SRC_UTIL_QUADRUPLE_BUILDER_H_
#define FIRESTORE_CORE_SRC_UTIL_QUADRUPLE_BUILDER_H_

#include <math.h>
#include <array>
#include <bit>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace firebase {
namespace firestore {
namespace util {

class QuadrupleBuilder {
 public:
  void parseDecimal(std::vector<uint8_t>& digits, int64_t exp10) {
    parse(digits, exp10);
  }
  // The fields containing the value of the instance
  uint32_t exponent;
  uint64_t mantHi;
  uint64_t mantLo;

 private:
  std::array<uint64_t, 4> buffer4x64B;
  std::array<uint64_t, 6> buffer6x32A;
  std::array<uint64_t, 6> buffer6x32B;
  std::array<uint64_t, 6> buffer6x32C;
  std::array<uint64_t, 12> buffer12x32;
  void parse(std::vector<uint8_t>& digits, int32_t exp10);
  int32_t parseMantissa(std::vector<uint8_t>& digits,
                        std::array<uint64_t, 6>& mantissa);
  template <std::size_t N>
  void divBuffBy10(std::array<uint64_t, N>& buffer);
  template <std::size_t N>
  bool isEmpty(std::array<uint64_t, N>& buffer);
  int32_t addCarry(std::vector<uint8_t>& digits);
  double findBinaryExponent(int32_t exp10, std::array<uint64_t, 6>& mantissa);
  double log2(double x);
  void findBinaryMantissa(int32_t exp10,
                          double exp2,
                          std::array<uint64_t, 6>& mantissa);
  void powerOfTwo(double exp, std::array<uint64_t, 4>& power);
  template <std::size_t N>
  void array_copy(std::array<uint64_t, N>& source,
                  std::array<uint64_t, 4>& dest);
  void multPacked3x64_AndAdjustExponent(std::array<uint64_t, 4>& factor1,
                                        std::array<uint64_t, 4>& factor2,
                                        std::array<uint64_t, 4>& result);
  void multPacked3x64_simply(std::array<uint64_t, 4>& factor1,
                             std::array<uint64_t, 4>& factor2,
                             std::array<uint64_t, 12>& result);
  template <std::size_t N>
  int32_t correctPossibleUnderflow(std::array<uint64_t, N>& mantissa);
  template <std::size_t N>
  bool isLessThanOne(std::array<uint64_t, N>& buffer);
  void multUnpacked6x32byPacked(std::array<uint64_t, 6>& factor1,
                                std::array<uint64_t, 4>& factor2,
                                std::array<uint64_t, 12>& product);
  template <std::size_t N>
  void multBuffBy10(std::array<uint64_t, N>& buffer);
  template <std::size_t N>
  int32_t normalizeMant(std::array<uint64_t, N>& mantissa);
  template <std::size_t N>
  int32_t roundUp(std::array<uint64_t, N>& mantissa);
  template <std::size_t N, std::size_t P>
  void pack_6x32_to_3x64(std::array<uint64_t, N>& unpackedMant,
                         std::array<uint64_t, P>& result);
  void unpack_3x64_to_6x32(std::array<uint64_t, 4>& qd192,
                           std::array<uint64_t, 6>& buff_6x32);
  template <std::size_t N>
  void divBuffByPower2(std::array<uint64_t, N>& buffer, int32_t exp2);
  template <std::size_t N>
  void addToBuff(std::array<uint64_t, N>& buff, int32_t idx, uint64_t summand);
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif