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

#include "Firestore/core/src/util/quadruple_builder.h"

#include <array>
#include <cmath>
#include <limits>

namespace firebase {
namespace firestore {
namespace util {
// 2^192 = 6.277e57, so the 58-th digit after point may affect the result
static constexpr int32_t MAX_MANTISSA_LENGTH = 59;
// Max value of the decimal exponent, corresponds to EXPONENT_OF_MAX_VALUE
static constexpr int32_t MAX_EXP10 = 646456993;
// Min value of the decimal exponent, corresponds to EXPONENT_OF_MIN_NORMAL
static constexpr int32_t MIN_EXP10 = -646457032;
// (2^63) / 10 =~ 9.223372e17
static constexpr double TWO_POW_63_DIV_10 = 922337203685477580.0;
// Just for convenience: 0x8000_0000_0000_0000L
// static constexpr uint64_t HIGH_BIT = 0x8000000000000000L;
// Just for convenience: 0x8000_0000L, 2^31
static constexpr double POW_2_31 = 2147483648.0;
// Just for convenience: 0x0000_0000_FFFF_FFFFL
static constexpr uint64_t LOWER_32_BITS = 0x00000000FFFFFFFFL;
// Just for convenience: 0xFFFF_FFFF_0000_0000L;
static constexpr uint64_t HIGHER_32_BITS = 0xFFFFFFFF00000000L;
// Approximate value of log<sub>2</sub>(10)
static const double LOG2_10 = log(10) / log(2);
// Approximate value of log<sub>2</sub>(e)
static const double LOG2_E = 1 / log(2.0);
// The value of the exponent (biased) corresponding to {@code 1.0 == 2^0};
// equals to 2_147_483_647
// ({@code 0x7FFF_FFFF}).
static constexpr int32_t EXPONENT_BIAS = 0x7FFFFFFF;
// The value of the exponent (biased), corresponding to {@code Infinity}, {@code
// _Infinty}, and
// {@code NaN}
static constexpr uint64_t EXPONENT_OF_INFINITY = 0xFFFFFFFFL;
// An array of positive powers of two, each value consists of 4 longs: decimal
// exponent and 3 x 64 bits of mantissa, divided by ten Used to find an
// arbitrary power of 2 (by powerOfTwo(long exp))
static std::array<std::array<uint64_t, 4>, 33> POS_POWERS_OF_2 = {
    {// 0: 2^0 =   1 = 0.1e1
     {{static_cast<uint64_t>(1), 0x1999999999999999LL, 0x9999999999999999LL,
       0x999999999999999aLL}},  // 1: 2^(2^0) =   2^1 =   2 = 0.2e1
     {{static_cast<uint64_t>(1), 0x3333333333333333LL, 0x3333333333333333LL,
       0x3333333333333334LL}},  // ***
                                // 2: 2^(2^1) =   2^2 =   4 = 0.4e1
     {{static_cast<uint64_t>(1), 0x6666666666666666LL, 0x6666666666666666LL,
       0x6666666666666667LL}},  // ***
                                // 3: 2^(2^2) =   2^4 =   16 = 0.16e2
     {{static_cast<uint64_t>(2), 0x28f5c28f5c28f5c2LL, 0x8f5c28f5c28f5c28LL,
       0xf5c28f5c28f5c290LL}},  // ***
                                // 4: 2^(2^3) =   2^8 =   256 = 0.256e3
     {{static_cast<uint64_t>(3), 0x4189374bc6a7ef9dLL, 0xb22d0e5604189374LL,
       0xbc6a7ef9db22d0e6LL}},  // ***
                                // 5: 2^(2^4) =   2^16 =   65536 = 0.65536e5
     {{static_cast<uint64_t>(5), 0xa7c5ac471b478423LL, 0x0fcf80dc33721d53LL,
       0xcddd6e04c0592104LL}},  // 6: 2^(2^5) =   2^32 =   4294967296 =
                                // 0.4294967296e10
     {{static_cast<uint64_t>(10), 0x6df37f675ef6eadfLL, 0x5ab9a2072d44268dLL,
       0x97df837e6748956eLL}},  // 7: 2^(2^6) =   2^64 =   18446744073709551616
                                // = 0.18446744073709551616e20
     {{static_cast<uint64_t>(20), 0x2f394219248446baLL, 0xa23d2ec729af3d61LL,
       0x0607aa0167dd94cbLL}},  // 8: 2^(2^7) =   2^128 =
                                // 340282366920938463463374607431768211456 =
                                // 0.340282366920938463463374607431768211456e39
     {{static_cast<uint64_t>(39), 0x571cbec554b60dbbLL, 0xd5f64baf0506840dLL,
       0x451db70d5904029bLL}},  // 9: 2^(2^8) =   2^256 =
                                // 1.1579208923731619542357098500868790785326998466564056403945758401E+77
                                // =
                                // 0.11579208923731619542357098500868790785326998466564056403945758401e78
     {{static_cast<uint64_t>(78), 0x1da48ce468e7c702LL, 0x6520247d3556476dLL,
       0x1469caf6db224cfaLL}},  // ***
                                // 10: 2^(2^9) =   2^512 =
                                // 1.3407807929942597099574024998205846127479365820592393377723561444E+154
                                // =
                                // 0.13407807929942597099574024998205846127479365820592393377723561444e155
     {{static_cast<uint64_t>(155), 0x2252f0e5b39769dcLL, 0x9ae2eea30ca3ade0LL,
       0xeeaa3c08dfe84e30LL}},  // 11: 2^(2^10) =   2^1024 =
                                // 1.7976931348623159077293051907890247336179769789423065727343008116E+308
                                // =
                                // 0.17976931348623159077293051907890247336179769789423065727343008116e309
     {{static_cast<uint64_t>(309), 0x2e055c9a3f6ba793LL, 0x16583a816eb60a59LL,
       0x22c4b0826cf1ebf7LL}},  // 12: 2^(2^11) =   2^2048 =
                                // 3.2317006071311007300714876688669951960444102669715484032130345428E+616
                                // =
                                // 0.32317006071311007300714876688669951960444102669715484032130345428e617
     {{static_cast<uint64_t>(617), 0x52bb45e9cf23f17fLL, 0x7688c07606e50364LL,
       0xb34479aa9d449a57LL}},  // 13: 2^(2^12) =   2^4096 =
                                // 1.0443888814131525066917527107166243825799642490473837803842334833E+1233
                                // =
                                // 0.10443888814131525066917527107166243825799642490473837803842334833e1234
     {{static_cast<uint64_t>(1234), 0x1abc81c8ff5f846cLL, 0x8f5e3c9853e38c97LL,
       0x45060097f3bf9296LL}},  // 14: 2^(2^13) =   2^8192 =
                                // 1.0907481356194159294629842447337828624482641619962326924318327862E+2466
                                // =
                                // 0.10907481356194159294629842447337828624482641619962326924318327862e2467
     {{static_cast<uint64_t>(2467), 0x1bec53b510daa7b4LL, 0x48369ed77dbb0eb1LL,
       0x3b05587b2187b41eLL}},  // 15: 2^(2^14) =   2^16384 =
                                // 1.1897314953572317650857593266280071307634446870965102374726748212E+4932
                                // =
                                // 0.11897314953572317650857593266280071307634446870965102374726748212e4933
     {{static_cast<uint64_t>(4933), 0x1e75063a5ba91326LL, 0x8abfb8e460016ae3LL,
       0x28008702d29e8a3cLL}},  // 16: 2^(2^15) =   2^32768 =
                                // 1.4154610310449547890015530277449516013481307114723881672343857483E+9864
                                // =
                                // 0.14154610310449547890015530277449516013481307114723881672343857483e9865
     {{static_cast<uint64_t>(9865), 0x243c5d8bb5c5fa55LL, 0x40c6d248c5881915LL,
       0x4c0fd99fd5befc22LL}},  // 17: 2^(2^16) =   2^65536 =
                                // 2.0035299304068464649790723515602557504478254755697514192650169737E+19728
                                // =
                                // 0.20035299304068464649790723515602557504478254755697514192650169737e19729
     {{static_cast<uint64_t>(19729), 0x334a5570c3f4ef3cLL, 0xa13c36c43f979c90LL,
       0xda7ac473555fb7a8LL}},  // 18: 2^(2^17) =   2^131072 =
                                // 4.0141321820360630391660606060388767343771510270414189955825538065E+39456
                                // =
                                // 0.40141321820360630391660606060388767343771510270414189955825538065e39457
     {{static_cast<uint64_t>(39457), 0x66c304445dd98f3bLL, 0xa8c293a20e47a41bLL,
       0x4c5b03dc12604964LL}},  // 19: 2^(2^18) =   2^262144 =
                                // 1.6113257174857604736195721184520050106440238745496695174763712505E+78913
                                // =
                                // 0.16113257174857604736195721184520050106440238745496695174763712505e78914
     {{static_cast<uint64_t>(78914), 0x293ffbf5fb028cc4LL, 0x89d3e5ff44238406LL,
       0x369a339e1bfe8c9bLL}},  // 20: 2^(2^19) =   2^524288 =
                                // 2.5963705678310007761265964957268828277447343763484560463573654868E+157826
                                // =
                                // 0.25963705678310007761265964957268828277447343763484560463573654868e157827
     {{static_cast<uint64_t>(157827), 0x427792fbb68e5d20LL,
       0x7b297cd9fc154b62LL,
       0xf09142114aa9a20cLL}},  // 21: 2^(2^20) =   2^1048576 =
                                // 6.7411401254990734022690651047042454376201859485326882846944915676E+315652
                                // =
                                // 0.67411401254990734022690651047042454376201859485326882846944915676e315653
     {{static_cast<uint64_t>(315653), 0xac92bc65ad5c08fcLL,
       0x00beeb115a566c19LL,
       0x4ba882d8a4622437LL}},  // 22: 2^(2^21) =   2^2097152 =
                                // 4.5442970191613663099961595907970650433180103994591456270882095573E+631305
                                // =
                                // 0.45442970191613663099961595907970650433180103994591456270882095573e631306
     {{static_cast<uint64_t>(631306), 0x745581440f92e80eLL,
       0x4da822cf7f896f41LL,
       0x509d598678164ecdLL}},  // 23: 2^(2^22) =   2^4194304 =
                                // 2.0650635398358879243991194945816501695274360493029670347841664177E+1262611
                                // =
                                // 0.20650635398358879243991194945816501695274360493029670347841664177e1262612
     {{static_cast<uint64_t>(1262612), 0x34dd99b4c69523a5LL,
       0x64bc2e8f0d8b1044LL,
       0xb03b1c96da5dd349LL}},  // 24: 2^(2^23) =   2^8388608 =
                                // 4.2644874235595278724327289260856157547554200794957122157246170406E+2525222
                                // =
                                // 0.42644874235595278724327289260856157547554200794957122157246170406e2525223
     {{static_cast<uint64_t>(2525223), 0x6d2bbea9d6d25a08LL,
       0xa0a4606a88e96b70LL,
       0x182063bbc2fe8520LL}},  // 25: 2^(2^24) =   2^16777216 =
                                // 1.8185852985697380078927713277749906189248596809789408311078112486E+5050445
                                // =
                                // 0.18185852985697380078927713277749906189248596809789408311078112486e5050446
     {{static_cast<uint64_t>(5050446), 0x2e8e47d63bfdd6e3LL,
       0x2b55fa8976eaa3e9LL,
       0x1a6b9d3086412a73LL}},  // 26: 2^(2^25) =   2^33554432 =
                                // 3.3072524881739831340558051919726975471129152081195558970611353362E+10100890
                                // =
                                // 0.33072524881739831340558051919726975471129152081195558970611353362e10100891
     {{static_cast<uint64_t>(10100891), 0x54aa68efa1d719dfLL,
       0xd8505806612c5c8fLL,
       0xad068837fee8b43aLL}},  // 27: 2^(2^26) =   2^67108864 =
                                // 1.0937919020533002449982468634925923461910249420785622990340704603E+20201781
                                // =
                                // 0.10937919020533002449982468634925923461910249420785622990340704603e20201782
     {{static_cast<uint64_t>(20201782), 0x1c00464ccb7bae77LL,
       0x9e3877784c77982cLL,
       0xd94af3b61717404fLL}},  // 28: 2^(2^27) =   2^134217728 =
                                // 1.1963807249973763567102377630870670302911237824129274789063323723E+40403562
                                // =
                                // 0.11963807249973763567102377630870670302911237824129274789063323723e40403563
     {{static_cast<uint64_t>(40403563), 0x1ea099c8be2b6cd0LL,
       0x8bfb6d539fa50466LL,
       0x6d3bc37e69a84218LL}},  // 29: 2^(2^28) =   2^268435456 =
                                // 1.4313268391452478724777126233530788980596273340675193575004129517E+80807124
                                // =
                                // 0.14313268391452478724777126233530788980596273340675193575004129517e80807125
     {{static_cast<uint64_t>(80807125), 0x24a457f466ce8d18LL,
       0xf2c8f3b81bc6bb59LL,
       0xa78c757692e02d49LL}},  // 30: 2^(2^29) =   2^536870912 =
                                // 2.0486965204575262773910959587280218683219330308711312100181276813E+161614248
                                // =
                                // 0.20486965204575262773910959587280218683219330308711312100181276813e161614249
     {{static_cast<uint64_t>(161614249), 0x347256677aba6b53LL,
       0x3fbf90d30611a67cLL,
       0x1e039d87e0bdb32bLL}},  // 31: 2^(2^30) =   2^1073741824 =
                                // 4.1971574329347753848087162337676781412761959309467052555732924370E+323228496
                                // =
                                // 0.41971574329347753848087162337676781412761959309467052555732924370e323228497
     {{static_cast<uint64_t>(323228497), 0x6b727daf0fd3432aLL,
       0x71f71121f9e4200fLL,
       0x8fcd9942d486c10cLL}},  // 32: 2^(2^31) =   2^2147483648 =
                                // 1.7616130516839633532074931497918402856671115581881347960233679023E+646456993
                                // =
                                // 0.17616130516839633532074931497918402856671115581881347960233679023e646456994
     {{static_cast<uint64_t>(646456994), 0x2d18e84484d91f78LL,
       0x4079bfe7829dec6fLL, 0x21551643e365abc6LL}}}};
// An array of negative powers of two, each value consists of 4 longs: decimal
// exponent and 3 x 64 bits of mantissa, divided by ten. Used to find an
// arbitrary power of 2 (by powerOfTwo(long exp))
static std::array<std::array<uint64_t, 4>, 33> NEG_POWERS_OF_2 = {
    {// v18
     // 0: 2^0 =   1 = 0.1e1
     {{static_cast<uint64_t>(1), 0x1999999999999999LL, 0x9999999999999999LL,
       0x999999999999999aLL}},  // 1: 2^-(2^0) =   2^-1 =   0.5 = 0.5e0
     {{static_cast<uint64_t>(0), 0x8000000000000000LL, 0x0000000000000000LL,
       0x0000000000000000LL}},  // 2: 2^-(2^1) =   2^-2 =   0.25 = 0.25e0
                                //      {0, 0x4000_0000_0000_0000L,
                                //      0x0000_0000_0000_0000L,
                                //      0x0000_0000_0000_0000L},
     {{static_cast<uint64_t>(0), 0x4000000000000000LL, 0x0000000000000000LL,
       0x0000000000000001LL}},  // ***
                                // 3: 2^-(2^2) =   2^-4 =   0.0625 = 0.625e-1
     {{static_cast<uint64_t>(-1), 0xa000000000000000LL, 0x0000000000000000LL,
       0x0000000000000000LL}},  // 4: 2^-(2^3) =   2^-8 =   0.00390625 =
                                // 0.390625e-2
     {{static_cast<uint64_t>(-2), 0x6400000000000000LL, 0x0000000000000000LL,
       0x0000000000000000LL}},  // 5: 2^-(2^4) =   2^-16 =   0.0000152587890625
                                // = 0.152587890625e-4
     {{static_cast<uint64_t>(-4), 0x2710000000000000LL, 0x0000000000000000LL,
       0x0000000000000001LL}},  // ***
                                // 6: 2^-(2^5) =   2^-32
                                // =   2.3283064365386962890625E-10 =
                                // 0.23283064365386962890625e-9
     {{static_cast<uint64_t>(-9), 0x3b9aca0000000000LL, 0x0000000000000000LL,
       0x0000000000000001LL}},  // ***
                                // 7: 2^-(2^6) =   2^-64
                                // =
                                // 0.542101086242752217003726400434970855712890625e-19
     {{static_cast<uint64_t>(-19), 0x8ac7230489e80000LL, 0x0000000000000000LL,
       0x0000000000000000LL}},  // 8: 2^-(2^7) =   2^-128 =
                                // 2.9387358770557187699218413430556141945466638919302188037718792657E-39
                                // =
                                // 0.29387358770557187699218413430556141945466638919302188037718792657e-38
     {{static_cast<uint64_t>(-38), 0x4b3b4ca85a86c47aLL, 0x098a224000000000LL,
       0x0000000000000001LL}},  // ***
                                // 9: 2^-(2^8) =   2^-256 =
                                // 8.6361685550944446253863518628003995711160003644362813850237034700E-78
                                // =
                                // 0.86361685550944446253863518628003995711160003644362813850237034700e-77
     {{static_cast<uint64_t>(-77), 0xdd15fe86affad912LL, 0x49ef0eb713f39ebeLL,
       0xaa987b6e6fd2a002LL}},  // 10: 2^-(2^9) =   2^-512 =
                                // 7.4583407312002067432909653154629338373764715346004068942715183331E-155
                                // =
                                // 0.74583407312002067432909653154629338373764715346004068942715183331e-154
     {{static_cast<uint64_t>(-154), 0xbeeefb584aff8603LL, 0xaafb550ffacfd8faLL,
       0x5ca47e4f88d45371LL}},  // 11: 2^-(2^10) =   2^-1024 =
                                // 5.5626846462680034577255817933310101605480399511558295763833185421E-309
                                // =
                                // 0.55626846462680034577255817933310101605480399511558295763833185421e-308
     {{static_cast<uint64_t>(-308), 0x8e679c2f5e44ff8fLL, 0x570f09eaa7ea7648LL,
       0x5961db50c6d2b888LL}},  // ***
                                // 12: 2^-(2^11) =   2^-2048 =
                                // 3.0943460473825782754801833699711978538925563038849690459540984582E-617
                                // =
                                // 0.30943460473825782754801833699711978538925563038849690459540984582e-616
     {{static_cast<uint64_t>(-616), 0x4f371b3399fc2ab0LL, 0x8170041c9feb05aaLL,
       0xc7c343447c75bcf6LL}},  // 13: 2^-(2^12) =   2^-4096 =
                                // 9.5749774609521853579467310122804202420597417413514981491308464986E-1234
                                // =
                                // 0.95749774609521853579467310122804202420597417413514981491308464986e-1233
     {{static_cast<uint64_t>(-1233), 0xf51e928179013fd3LL, 0xde4bd12cde4d985cLL,
       0x4a573ca6f94bff14LL}},  // 14: 2^-(2^13) =   2^-8192 =
                                // 9.1680193377742358281070619602424158297818248567928361864131947526E-2467
                                // =
                                // 0.91680193377742358281070619602424158297818248567928361864131947526e-2466
     {{static_cast<uint64_t>(-2466), 0xeab388127bccaff7LL, 0x1667639142b9fbaeLL,
       0x775ec9995e1039fbLL}},  // 15: 2^-(2^14) =   2^-16384 =
                                // 8.4052578577802337656566945433043815064951983621161781002720680748E-4933
                                // =
                                // 0.84052578577802337656566945433043815064951983621161781002720680748e-4932
     {{static_cast<uint64_t>(-4932), 0xd72cb2a95c7ef6ccLL, 0xe81bf1e825ba7515LL,
       0xc2feb521d6cb5dcdLL}},  // 16: 2^-(2^15) =   2^-32768 =
                                // 7.0648359655776364427774021878587184537374439102725065590941425796E-9865
                                // =
                                // 0.70648359655776364427774021878587184537374439102725065590941425796e-9864
     {{static_cast<uint64_t>(-9864), 0xb4dc1be6604502dcLL, 0xd491079b8eef6535LL,
       0x578d3965d24de84dLL}},  // ***
                                // 17: 2^-(2^16) =   2^-65536 =
                                // 4.9911907220519294656590574792132451973746770423207674161425040336E-19729
                                // =
                                // 0.49911907220519294656590574792132451973746770423207674161425040336e-19728
     {{static_cast<uint64_t>(-19728), 0x7fc6447bee60ea43LL,
       0x2548da5c8b125b27LL,
       0x5f42d1142f41d349LL}},  // ***
                                // 18: 2^-(2^17) =   2^-131072 =
                                // 2.4911984823897261018394507280431349807329035271689521242878455599E-39457
                                // =
                                // 0.24911984823897261018394507280431349807329035271689521242878455599e-39456
     {{static_cast<uint64_t>(-39456), 0x3fc65180f88af8fbLL,
       0x6a6915f383349413LL,
       0x063c3708b6ceb291LL}},  // ***
                                // 19: 2^-(2^18) =   2^-262144 =
                                // 6.2060698786608744707483205572846793091942192651991171731773832448E-78914
                                // =
                                // 0.62060698786608744707483205572846793091942192651991171731773832448e-78913
     {{static_cast<uint64_t>(-78913), 0x9ee0197c8dcd55bfLL,
       0x2b2b9b942c38f4a2LL,
       0x0f8ba634e9c706aeLL}},  // 20: 2^-(2^19) =   2^-524288 =
                                // 3.8515303338821801176537443725392116267291403078581314096728076497E-157827
                                // =
                                // 0.38515303338821801176537443725392116267291403078581314096728076497e-157826
     {{static_cast<uint64_t>(-157826), 0x629963a25b8b2d79LL,
       0xd00b9d2286f70876LL,
       0xe97004700c3644fcLL}},  // ***
                                // 21: 2^-(2^20) =   2^-1048576 =
                                // 1.4834285912814577854404052243709225888043963245995136935174170977E-315653
                                // =
                                // 0.14834285912814577854404052243709225888043963245995136935174170977e-315652
     {{static_cast<uint64_t>(-315652), 0x25f9cc308ceef4f3LL,
       0x40f19543911a4546LL,
       0xa2cd389452cfc366LL}},  // 22: 2^-(2^21) =   2^-2097152 =
                                // 2.2005603854312903332428997579002102976620485709683755186430397089E-631306
                                // =
                                // 0.22005603854312903332428997579002102976620485709683755186430397089e-631305
     {{static_cast<uint64_t>(-631305), 0x385597b0d47e76b8LL,
       0x1b9f67e103bf2329LL,
       0xc3119848595985f7LL}},  // 23: 2^-(2^22) =   2^-4194304 =
                                // 4.8424660099295090687215589310713586524081268589231053824420510106E-1262612
                                // =
                                // 0.48424660099295090687215589310713586524081268589231053824420510106e-1262611
     {{static_cast<uint64_t>(-1262611), 0x7bf795d276c12f66LL,
       0x66a61d62a446659aLL,
       0xa1a4d73bebf093d5LL}},  // ***
                                // 24: 2^-(2^23) =   2^-8388608 =
                                // 2.3449477057322620222546775527242476219043877555386221929831430440E-2525223
                                // =
                                // 0.23449477057322620222546775527242476219043877555386221929831430440e-2525222
     {{static_cast<uint64_t>(-2525222), 0x3c07d96ab1ed7799LL,
       0xcb7355c22cc05ac0LL,
       0x4ffc0ab73b1f6a49LL}},  // ***
                                // 25: 2^-(2^24) =   2^-16777216 =
                                // 5.4987797426189993226257377747879918011694025935111951649826798628E-5050446
                                // =
                                // 0.54987797426189993226257377747879918011694025935111951649826798628e-5050445
     {{static_cast<uint64_t>(-5050445), 0x8cc4cd8c3edefb9aLL,
       0x6c8ff86a90a97e0cLL,
       0x166cfddbf98b71bfLL}},  // ***
                                // 26: 2^-(2^25) =   2^-33554432 =
                                // 3.0236578657837068435515418409027857523343464783010706819696074665E-10100891
                                // =
                                // 0.30236578657837068435515418409027857523343464783010706819696074665e-10100890
     {{static_cast<uint64_t>(-10100890), 0x4d67d81cc88e1228LL,
       0x1d7cfb06666b79b3LL,
       0x7b916728aaa4e70dLL}},  // ***
                                // 27: 2^-(2^26) =   2^-67108864 =
                                // 9.1425068893156809483320844568740945600482370635012633596231964471E-20201782
                                // =
                                // 0.91425068893156809483320844568740945600482370635012633596231964471e-20201781
     {{static_cast<uint64_t>(-20201781), 0xea0c55494e7a552dLL,
       0xb88cb9484bb86c61LL,
       0x8d44893c610bb7dFLL}},  // ***
                                // 28: 2^-(2^27) =   2^-134217728 =
                                // 8.3585432221184688810803924874542310018191301711943564624682743545E-40403563
                                // =
                                // 0.83585432221184688810803924874542310018191301711943564624682743545e-40403562
     {{static_cast<uint64_t>(-40403562), 0xd5fa8c821ec0c24aLL,
       0xa80e46e764e0f8b0LL,
       0xa7276bfa432fac7eLL}},  // 29: 2^-(2^28) =   2^-268435456 =
                                // 6.9865244796022595809958912202005005328020601847785697028605460277E-80807125
                                // =
                                // 0.69865244796022595809958912202005005328020601847785697028605460277e-80807124
     {{static_cast<uint64_t>(-80807124), 0xb2dae307426f6791LL,
       0xc970b82f58b12918LL,
       0x0472592f7f39190eLL}},  // 30: 2^-(2^29) =   2^-536870912 =
                                // 4.8811524304081624052042871019605298977947353140996212667810837790E-161614249
                                // =
                                // 0.48811524304081624052042871019605298977947353140996212667810837790e-161614248
                                //      {-161614248, 0x7cf5_1edd_8a15_f1c9L,
                                //      0x656d_ab34_98f8_e697L,
                                //      0x12da_a2a8_0e53_c809L},
     {{static_cast<uint64_t>(-161614248), 0x7cf51edd8a15f1c9LL,
       0x656dab3498f8e697LL,
       0x12daa2a80e53c807LL}},  // 31: 2^-(2^30) =   2^-1073741824 =
                                // 2.3825649048879510732161697817326745204151961255592397879550237608E-323228497
                                // =
                                // 0.23825649048879510732161697817326745204151961255592397879550237608e-323228496
     {{static_cast<uint64_t>(-323228496), 0x3cfe609ab5883c50LL,
       0xbec8b5d22b198871LL,
       0xe18477703b4622b4LL}},  // 32: 2^-(2^31) =   2^-2147483648 =
                                // 5.6766155260037313438164181629489689531186932477276639365773003794E-646456994
                                // =
                                // 0.56766155260037313438164181629489689531186932477276639365773003794e-646456993
     {{static_cast<uint64_t>(-646456993), 0x9152447b9d7cda9aLL,
       0x3b4d3f6110d77aadLL, 0xfa81bad1c394adb4LL}}}};
// Buffers used internally
// The order of words in the arrays is big-endian: the highest part is in
// buff[0] (in buff[1] for buffers of 10 words)

void QuadrupleBuilder::parse(std::vector<uint8_t>& digits, int32_t exp10) {
  exp10 += static_cast<int32_t>((digits).size()) -
           1;  // digits is viewed as x.yyy below.
  this->exponent = 0;
  this->mantHi = 0LL;
  this->mantLo = 0LL;
  // Finds numeric value of the decimal mantissa
  std::array<uint64_t, 6>& mantissa = this->buffer6x32C;
  int32_t exp10Corr = parseMantissa(digits, mantissa);
  if (exp10Corr == 0 && isEmpty(mantissa)) {
    // Mantissa == 0
    return;
  }
  // takes account of the point position in the mant string and possible carry
  // as a result of round-up (like 9.99e1 -> 1.0e2)
  exp10 += exp10Corr;
  if (exp10 < MIN_EXP10) {
    return;
  }
  if (exp10 > MAX_EXP10) {
    this->exponent = (static_cast<uint32_t>(EXPONENT_OF_INFINITY));
    return;
  }
  double exp2 = findBinaryExponent(exp10, mantissa);
  // Finds binary mantissa and possible exponent correction. Fills the fields.
  findBinaryMantissa(exp10, exp2, mantissa);
}
int32_t QuadrupleBuilder::parseMantissa(std::vector<uint8_t>& digits,
                                        std::array<uint64_t, 6>& mantissa) {
  for (int32_t i = (0); i < (6); i++) {
    mantissa[i] = 0LL;
  }
  // Skip leading zeroes
  int32_t firstDigit = 0;
  while (firstDigit < static_cast<int32_t>((digits).size()) &&
         digits[firstDigit] == 0) {
    firstDigit += 1;
  }
  if (firstDigit == static_cast<int32_t>((digits).size())) {
    return 0;  // All zeroes
  }
  int32_t expCorr = -firstDigit;
  // Limit the string length to avoid unnecessary fuss
  if (static_cast<int32_t>((digits).size()) - firstDigit >
      MAX_MANTISSA_LENGTH) {
    bool carry =
        digits[MAX_MANTISSA_LENGTH] >= 5;  // The highest digit to be truncated
    std::vector<uint8_t> truncated(MAX_MANTISSA_LENGTH);
    for (int32_t i = (0); i < (MAX_MANTISSA_LENGTH); i++) {
      truncated[i] = digits[i + firstDigit];
    }
    if (carry) {  // Round-up: add carry
      expCorr += addCarry(
          truncated);  // May add an extra digit in front of it (99..99 -> 100)
    }
    digits = truncated;
    firstDigit = 0;
  }
  for (int32_t i = (static_cast<int32_t>((digits).size())) - 1;
       i >= (firstDigit); i--) {  // digits, starting from the last
    mantissa[0] |= (static_cast<uint64_t>(digits[i])) << 32LL;
    divBuffBy10(mantissa);
  }
  return expCorr;
}
// Divides the unpacked value stored in the given buffer by 10
// @param buffer contains the unpacked value to divide (32 least significant
// bits are used)
template <std::size_t N>
void QuadrupleBuilder::divBuffBy10(std::array<uint64_t, N>& buffer) {
  int32_t maxIdx = static_cast<int32_t>((buffer).size());
  // big/endian
  for (int32_t i = (0); i < (maxIdx); i++) {
    uint64_t r = buffer[i] % 10LL;
    buffer[i] = ((buffer[i]) / (10LL));
    if (i + 1 < maxIdx) {
      buffer[i + 1] += r << 32LL;
    }
  }
}
// Checks if the buffer is empty (contains nothing but zeros)
// @param buffer the buffer to check
// @return {@code true} if the buffer is empty, {@code false} otherwise
template <std::size_t N>
bool QuadrupleBuilder::isEmpty(std::array<uint64_t, N>& buffer) {
  for (int32_t i = (0); i < (static_cast<int32_t>((buffer).size())); i++) {
    if (buffer[i] != 0LL) {
      return false;
    }
  }
  return true;
}
// Adds one to a decimal number represented as a sequence of decimal digits.
// propagates carry as needed, so that {@code addCarryTo("6789") = "6790",
// addCarryTo("9999") = "10000"} etc.
// @return 1 if an additional higher "1" was added in front of the number as a
// result of
//     rounding-up, 0 otherwise
int32_t QuadrupleBuilder::addCarry(std::vector<uint8_t>& digits) {
  for (int32_t i = (static_cast<int32_t>((digits).size())) - 1; i >= (0);
       i--) {  // starting with the lowest digit
    uint8_t c = digits[i];
    if (c == 9) {
      digits[i] = 0;
    } else {
      digits[i] = (static_cast<uint8_t>(digits[i] + 1));
      return 0;
    }
  }
  digits[0] = 1;
  return 1;
}
// Finds binary exponent, using decimal exponent and mantissa.<br>
// exp2 = exp10 * log<sub>2</sub>(10) + log<sub>2</sub>(mant)<br>
// @param exp10 decimal exponent
// @param mantissa array of longs containing decimal mantissa (divided by 10)
// @return found value of binary exponent
double QuadrupleBuilder::findBinaryExponent(int32_t exp10,
                                            std::array<uint64_t, 6>& mantissa) {
  uint64_t mant10 =
      mantissa[0] << 31LL |
      ((mantissa[1]) >> (1LL));  // Higher 63 bits of the mantissa, in range
  // 0x0CC..CCC -- 0x7FF..FFF (2^63/10 -- 2^63-1)
  // decimal value of the mantissa in range 1.0..9.9999...
  double mant10d = (static_cast<double>(mant10)) / TWO_POW_63_DIV_10;
  return floor((static_cast<double>(exp10)) * LOG2_10 +
               log2(mant10d));  // Binary exponent
}
// Calculates log<sub>2</sub> of the given x
// @param x argument that can't be 0
// @return the value of log<sub>2</sub>(x)
double QuadrupleBuilder::log2(double x) {
  // x can't be 0
  return LOG2_E * log(x);
}
void QuadrupleBuilder::findBinaryMantissa(int32_t exp10,
                                          double exp2,
                                          std::array<uint64_t, 6>& mantissa) {
  // pow(2, -exp2): division by 2^exp2 is multiplication by 2^(-exp2) actually
  std::array<uint64_t, 4>& powerOf2 = this->buffer4x64B;
  powerOfTwo(-exp2, powerOf2);
  std::array<uint64_t, 12>& product =
      this->buffer12x32;  // use it for the product (M * 10^E / 2^e)
  multUnpacked6x32byPacked(mantissa, powerOf2,
                           product);  // product in buff_12x32
  multBuffBy10(product);  // "Quasidecimals" are numbers divided by 10
  // The powerOf2[0] is stored as an unsigned value
  if ((static_cast<uint64_t>(powerOf2[0])) != (static_cast<uint64_t>(-exp10))) {
    // For some combinations of exp2 and exp10, additional multiplication needed
    // (see mant2_from_M_E_e.xls)
    multBuffBy10(product);
  }
  // compensate possible inaccuracy of logarithms used to compute exp2
  exp2 += normalizeMant(product);
  exp2 += EXPONENT_BIAS;  // add bias
  // For subnormal values, exp2 <= 0. We just return 0 for them, as they are
  // far from any range we are interested in.
  if (exp2 <= 0) {
    return;
  }
  exp2 += roundUp(product);  // round up, may require exponent correction
  if ((static_cast<uint64_t>(exp2)) >= EXPONENT_OF_INFINITY) {
    this->exponent = (static_cast<uint32_t>(EXPONENT_OF_INFINITY));
  } else {
    this->exponent = (static_cast<uint32_t>(exp2));
    this->mantHi = (static_cast<uint64_t>((product[0] << 32LL) + product[1]));
    this->mantLo = (static_cast<uint64_t>((product[2] << 32LL) + product[3]));
  }
}
// Calculates the required power and returns the result in the quasidecimal
// format (an array of longs, where result[0] is the decimal exponent of the
// resulting value, and result[1] -- result[3] contain 192 bits of the mantissa
// divided by ten (so that 8 looks like <pre>{@code {1, 0xCCCC_.._CCCCL,
// 0xCCCC_.._CCCCL, 0xCCCC_.._CCCDL}}}</pre> uses arrays <b><i>buffer4x64B</b>,
// buffer6x32A, buffer6x32B, buffer12x32</i></b>,
// @param exp the power to raise 2 to
// @param power (result) the value of {@code2^exp}
void QuadrupleBuilder::powerOfTwo(double exp, std::array<uint64_t, 4>& power) {
  if (exp == 0) {
    array_copy(POS_POWERS_OF_2[0], power);
    return;
  }
  // positive powers of 2 (2^0, 2^1, 2^2, 2^4, 2^8 ... 2^(2^31) )
  std::array<std::array<uint64_t, 4>, 33>* powers = (&(POS_POWERS_OF_2));
  if (exp < 0) {
    exp = -exp;
    powers = (&(NEG_POWERS_OF_2));  // positive powers of 2 (2^0, 2^-1, 2^-2,
                                    // 2^-4, 2^-8 ... 2^30)
  }
  // 2^31 = 0x8000_0000L; a single bit that will be shifted right at every
  // iteration
  double currPowOf2 = POW_2_31;
  int32_t idx = 32;  // Index in the table of powers
  bool first_power = true;
  // if exp = b31 * 2^31 + b30 * 2^30 + .. + b0 * 2^0, where b0..b31 are the
  // values of the bits in exp, then 2^exp = 2^b31 * 2^b30 ... * 2^b0. Find the
  // product, using a table of powers of 2.
  while (exp > 0) {
    if (exp >= currPowOf2) {  // the current bit in the exponent is 1
      if (first_power) {
        // 4 longs, power[0] -- decimal (?) exponent, power[1..3] -- 192 bits of
        // mantissa
        array_copy((*(powers))[idx], power);
        first_power = false;
      } else {
        // Multiply by the corresponding power of 2
        multPacked3x64_AndAdjustExponent(power, (*(powers))[idx], power);
      }
      exp -= currPowOf2;
    }
    idx -= 1;
    currPowOf2 = currPowOf2 * 0.5;  // Note: this is exact
  }
}
// Copies from into to.
template <std::size_t N>
void QuadrupleBuilder::array_copy(std::array<uint64_t, N>& source,
                                  std::array<uint64_t, 4>& dest) {
  for (int32_t i = (0); i < (static_cast<int32_t>((dest).size())); i++) {
    dest[i] = source[i];
  }
}
// Multiplies two quasidecimal numbers contained in buffers of 3 x 64 bits with
// exponents, puts the product to <b><i>buffer4x64B</i></b><br> and returns it.
// Both each of the buffers and the product contain 4 longs - exponent and 3 x
// 64 bits of mantissa. If the higher word of mantissa of the product is less
// than 0x1999_9999_9999_9999L (i.e. mantissa is less than 0.1) multiplies
// mantissa by 10 and adjusts the exponent respectively.
void QuadrupleBuilder::multPacked3x64_AndAdjustExponent(
    std::array<uint64_t, 4>& factor1,
    std::array<uint64_t, 4>& factor2,
    std::array<uint64_t, 4>& result) {
  multPacked3x64_simply(factor1, factor2, this->buffer12x32);
  int32_t expCorr = correctPossibleUnderflow(this->buffer12x32);
  pack_6x32_to_3x64(this->buffer12x32, result);
  // result[0] is a signed int64 value stored in an uint64
  result[0] =
      factor1[0] + factor2[0] +
      (static_cast<uint64_t>(expCorr));  // product.exp = f1.exp + f2.exp
}
// Multiplies mantissas of two packed quasidecimal values (each is an array of 4
// longs, exponent + 3 x 64 bits of mantissa) Returns the product as unpacked
// buffer of 12 x 32 (12 x 32 bits of product) uses arrays <b><i>buffer6x32A,
// buffer6x32B</b></i>
// @param factor1 an array of longs containing factor 1 as packed quasidecimal
// @param factor2 an array of longs containing factor 2 as packed quasidecimal
// @param result an array of 12 longs filled with the product of mantissas
void QuadrupleBuilder::multPacked3x64_simply(std::array<uint64_t, 4>& factor1,
                                             std::array<uint64_t, 4>& factor2,
                                             std::array<uint64_t, 12>& result) {
  for (int32_t i = (0); i < (static_cast<int32_t>((result).size())); i++) {
    result[i] = 0LL;
  }
  // TODO(dgay): 19.01.16 21:23:06 for the next version -- rebuild the table of
  //  powers to make the numbers unpacked, to avoid packing/unpacking
  unpack_3x64_to_6x32(factor1, this->buffer6x32A);
  unpack_3x64_to_6x32(factor2, this->buffer6x32B);
  for (int32_t i = (6) - 1; i >= (0); i--) {  // compute partial 32-bit products
    for (int32_t j = (6) - 1; j >= (0); j--) {
      uint64_t part = this->buffer6x32A[i] * this->buffer6x32B[j];
      result[j + i + 1] =
          (static_cast<uint64_t>(result[j + i + 1] + (part & LOWER_32_BITS)));
      result[j + i] =
          (static_cast<uint64_t>(result[j + i] + ((part) >> (32LL))));
    }
  }
  // Carry higher bits of the product to the lower bits of the next word
  for (int32_t i = (12) - 1; i >= (1); i--) {
    result[i - 1] =
        (static_cast<uint64_t>(result[i - 1] + ((result[i]) >> (32LL))));
    result[i] &= LOWER_32_BITS;
  }
}
// Corrects possible underflow of the decimal mantissa, passed in in the {@code
// mantissa}, by multiplying it by a power of ten. The corresponding value to
// adjust the decimal exponent is returned as the result
// @param mantissa a buffer containing the mantissa to be corrected
// @return a corrective (addition) that is needed to adjust the decimal exponent
// of the number
template <std::size_t N>
int32_t QuadrupleBuilder::correctPossibleUnderflow(
    std::array<uint64_t, N>& mantissa) {
  int32_t expCorr = 0;
  while (isLessThanOne(mantissa)) {  // Underflow
    multBuffBy10(mantissa);
    expCorr -= 1;
  }
  return expCorr;
}
// Checks if the unpacked quasidecimal value held in the given buffer is less
// than one (in this format, one is represented as { 0x1999_9999L, 0x9999_9999L,
// 0x9999_9999L,...}
// @param buffer a buffer containing the value to check
// @return {@code true}, if the value is less than one
template <std::size_t N>
bool QuadrupleBuilder::isLessThanOne(std::array<uint64_t, N>& buffer) {
  if (buffer[0] < 0x19999999LL) {
    return true;
  }
  if (buffer[0] > 0x19999999LL) {
    return false;
  }
  // A note regarding the coverage:
  // Multiplying a 128-bit number by another 192-bit number,
  // as well as multiplying of two 192-bit numbers,
  // can never produce 320 (or 384 bits, respectively) of 0x1999_9999L,
  // 0x9999_9999L,
  for (int32_t i = (1); i < (static_cast<int32_t>((buffer).size())); i++) {
    // so this loop can't be covered entirely
    if (buffer[i] < 0x99999999LL) {
      return true;
    }
    if (buffer[i] > 0x99999999LL) {
      return false;
    }
  }
  // and it can never reach this point in real life.
  return false;  // Still Java requires the return statement here.
}
// Multiplies unpacked 192-bit value by a packed 192-bit factor <br>
// uses static arrays <b><i>buffer6x32B</i></b>
// @param factor1 a buffer containing unpacked quasidecimal mantissa (6 x 32
// bits)
// @param factor2 an array of 4 longs containing packed quasidecimal power of
// two
// @param product a buffer of at least 12 longs to hold the product
void QuadrupleBuilder::multUnpacked6x32byPacked(
    std::array<uint64_t, 6>& factor1,
    std::array<uint64_t, 4>& factor2,
    std::array<uint64_t, 12>& product) {
  for (int32_t i = (0); i < (static_cast<int32_t>((product).size())); i++) {
    product[i] = 0LL;
  }
  std::array<uint64_t, 6>& unpacked2 = this->buffer6x32B;
  unpack_3x64_to_6x32(
      factor2, unpacked2);  // It's the powerOf2, with exponent in 0'th word
  int32_t maxFactIdx = static_cast<int32_t>((factor1).size());
  for (int32_t i = (maxFactIdx)-1; i >= (0);
       i--) {  // compute partial 32-bit products
    for (int32_t j = (maxFactIdx)-1; j >= (0); j--) {
      uint64_t part = factor1[i] * unpacked2[j];
      product[j + i + 1] =
          (static_cast<uint64_t>(product[j + i + 1] + (part & LOWER_32_BITS)));
      product[j + i] =
          (static_cast<uint64_t>(product[j + i] + ((part) >> (32LL))));
    }
  }
  // Carry higher bits of the product to the lower bits of the next word
  for (int32_t i = (12) - 1; i >= (1); i--) {
    product[i - 1] =
        (static_cast<uint64_t>(product[i - 1] + ((product[i]) >> (32LL))));
    product[i] &= LOWER_32_BITS;
  }
}
// Multiplies the unpacked value stored in the given buffer by 10
// @param buffer contains the unpacked value to multiply (32 least significant
// bits are used)
template <std::size_t N>
void QuadrupleBuilder::multBuffBy10(std::array<uint64_t, N>& buffer) {
  int32_t maxIdx = static_cast<int32_t>((buffer).size()) - 1;
  buffer[0] &= LOWER_32_BITS;
  buffer[maxIdx] *= 10LL;
  for (int32_t i = (maxIdx)-1; i >= (0); i--) {
    buffer[i] =
        (static_cast<uint64_t>(buffer[i] * 10LL + ((buffer[i + 1]) >> (32LL))));
    buffer[i + 1] &= LOWER_32_BITS;
  }
}
// Makes sure that the (unpacked) mantissa is normalized,
// i.e. buff[0] contains 1 in bit 32 (the implied integer part) and higher 32 of
// mantissa in bits 31..0, and buff[1]..buff[4] contain other 96 bits of
// mantissa in their lower halves: <pre>0x0000_0001_XXXX_XXXXL,
// 0x0000_0000_XXXX_XXXXL...</pre> If necessary, divides the mantissa by
// appropriate power of 2 to make it normal.
// @param mantissa a buffer containing unpacked mantissa
// @return if the mantissa was not normal initially, a correction that should be
// added to the result's exponent, or 0 otherwise
template <std::size_t N>
int32_t QuadrupleBuilder::normalizeMant(std::array<uint64_t, N>& mantissa) {
  int32_t expCorr = 31 - __builtin_clzll(mantissa[0]);
  if (expCorr != 0) {
    divBuffByPower2(mantissa, expCorr);
  }
  return expCorr;
}
// Rounds up the contents of the unpacked buffer to 128 bits by adding unity one
// bit lower than the lowest of these 128 bits. If carry propagates up to bit 33
// of buff[0], shifts the buffer rightwards to keep it normalized.
// @param mantissa the buffer to get rounded
// @return 1 if the buffer was shifted, 0 otherwise
template <std::size_t N>
int32_t QuadrupleBuilder::roundUp(std::array<uint64_t, N>& mantissa) {
  // due to the limited precision of the power of 2, a number with exactly half
  // LSB in its mantissa (i.e that would have 0x8000_0000_0000_0000L in bits
  // 128..191 if it were computed precisely), after multiplication by this power
  // of 2, may get erroneous bits 185..191 (counting from the MSB), taking a
  // value from 0xXXXX_XXXX_XXXX_XXXXL 0xXXXX_XXXX_XXXX_XXXXL
  // 0x7FFF_FFFF_FFFF_FFD8L. to 0xXXXX_XXXX_XXXX_XXXXL 0xXXXX_XXXX_XXXX_XXXXL
  // 0x8000_0000_0000_0014L, or something alike. To round it up, we first add
  // 0x0000_0000_0000_0000L 0x0000_0000_0000_0000L 0x0000_0000_0000_0028L, to
  // turn it into 0xXXXX_XXXX_XXXX_XXXXL 0xXXXX_XXXX_XXXX_XXXXL
  // 0x8000_0000_0000_00XXL, and then add 0x0000_0000_0000_0000L
  // 0x0000_0000_0000_0000L 0x8000_0000_0000_0000L, to provide carry to higher
  // bits.
  addToBuff(mantissa, 5, 100LL);  // to compensate possible inaccuracy
  addToBuff(mantissa, 4,
            0x80000000LL);  // round-up, if bits 128..159 >= 0x8000_0000L
  if ((mantissa[0] & (HIGHER_32_BITS << 1LL)) != 0LL) {
    // carry's got propagated beyond the highest bit
    divBuffByPower2(mantissa, 1);
    return 1;
  }
  return 0;
}
// converts 192 most significant bits of the mantissa of a number from an
// unpacked quasidecimal form (where 32 least significant bits only used) to a
// packed quasidecimal form (where buff[0] contains the exponent and
// buff[1]..buff[3] contain 3 x 64 = 192 bits of mantissa)
// @param unpackedMant a buffer of at least 6 longs containing an unpacked value
// @param result a buffer of at least 4 long to hold the packed value
// @return packedQD192 with words 1..3 filled with the packed mantissa.
// packedQD192[0] is not
//     affected.
template <std::size_t N, std::size_t P>
void QuadrupleBuilder::pack_6x32_to_3x64(std::array<uint64_t, N>& unpackedMant,
                                         std::array<uint64_t, P>& result) {
  result[1] = (unpackedMant[0] << 32LL) + unpackedMant[1];
  result[2] = (unpackedMant[2] << 32LL) + unpackedMant[3];
  result[3] = (unpackedMant[4] << 32LL) + unpackedMant[5];
}
// Unpacks the mantissa of a 192-bit quasidecimal (4 longs: exp10, mantHi,
// mantMid, mantLo) to a buffer of 6 longs, where the least significant 32 bits
// of each long contains respective 32 bits of the mantissa
// @param qd192 array of 4 longs containing the number to unpack
// @param buff_6x32 buffer of 6 long to hold the unpacked mantissa
void QuadrupleBuilder::unpack_3x64_to_6x32(std::array<uint64_t, 4>& qd192,
                                           std::array<uint64_t, 6>& buff_6x32) {
  buff_6x32[0] = ((qd192[1]) >> (32LL));
  buff_6x32[1] = qd192[1] & LOWER_32_BITS;
  buff_6x32[2] = ((qd192[2]) >> (32LL));
  buff_6x32[3] = qd192[2] & LOWER_32_BITS;
  buff_6x32[4] = ((qd192[3]) >> (32LL));
  buff_6x32[5] = qd192[3] & LOWER_32_BITS;
}
// Divides the contents of the buffer by 2^exp2<br>
// (shifts the buffer rightwards by exp2 if the exp2 is positive, and leftwards
// if it's negative), keeping it unpacked (only lower 32 bits of each element
// are used, except the buff[0] whose higher half is intended to contain integer
// part)
// @param buffer the buffer to divide
// @param exp2 the exponent of the power of two to divide by, expected to be
template <std::size_t N>
void QuadrupleBuilder::divBuffByPower2(std::array<uint64_t, N>& buffer,
                                       int32_t exp2) {
  int32_t maxIdx = static_cast<int32_t>((buffer).size()) - 1;
  uint64_t backShift =
      (static_cast<uint64_t>(32 - static_cast<int32_t>(labs(exp2))));
  if (exp2 > 0) {  // Shift to the right
    uint64_t exp2Shift = (static_cast<uint64_t>(exp2));
    for (int32_t i = (maxIdx + 1) - 1; i >= (1); i--) {
      buffer[i] = ((buffer[i]) >> (exp2Shift)) |
                  ((buffer[i - 1] << backShift) & LOWER_32_BITS);
    }
    buffer[0] =
        ((buffer[0]) >> (exp2Shift));  // Preserve the high half of buff[0]
  } else if (exp2 < 0) {               // Shift to the left
    uint64_t exp2Shift = (static_cast<uint64_t>(-exp2));
    buffer[0] = (static_cast<uint64_t>(
        (buffer[0] << exp2Shift) |
        ((buffer[1]) >> (backShift))));  // Preserve the high half of buff[0]
    for (int32_t i = (1); i < (maxIdx); i++) {
      buffer[i] =
          (static_cast<uint64_t>(((buffer[i] << exp2Shift) & LOWER_32_BITS) |
                                 ((buffer[i + 1]) >> (backShift))));
    }
    buffer[maxIdx] = (buffer[maxIdx] << exp2Shift) & LOWER_32_BITS;
  }
}
// Adds the summand to the idx'th word of the unpacked value stored in the
// buffer and propagates carry as necessary
// @param buff the buffer to add the summand to
// @param idx  the index of the element to which the summand is to be added
// @param summand the summand to add to the idx'th element of the buffer
template <std::size_t N>
void QuadrupleBuilder::addToBuff(std::array<uint64_t, N>& buff,
                                 int32_t idx,
                                 uint64_t summand) {
  int32_t maxIdx = idx;
  buff[maxIdx] = (static_cast<uint64_t>(
      buff[maxIdx] + summand));  // Big-endian, the lowest word
  for (int32_t i = (maxIdx + 1) - 1; i >= (1);
       i--) {  // from the lowest word upwards, except the highest
    if ((buff[i] & HIGHER_32_BITS) != 0LL) {
      buff[i] &= LOWER_32_BITS;
      buff[i - 1] += 1LL;
    } else {
      break;
    }
  }
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
