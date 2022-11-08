/*
 * Copyright 2022 Google LLC
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

#include "Firestore/core/src/util/logic_utils.h"

#include "Firestore/core/src/core/composite_filter.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/filter.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

using core::CompositeFilter;
using core::FieldFilter;
using testutil::AndFilters;
using testutil::Array;
using testutil::OrFilters;

namespace {

/** Helper method to get unique filters */
FieldFilter NameFilter(const char* name) {
  return testutil::Filter("name", "==", name);
}

const FieldFilter A = NameFilter("A");
const FieldFilter B = NameFilter("B");
const FieldFilter C = NameFilter("C");
const FieldFilter D = NameFilter("D");
const FieldFilter E = NameFilter("E");
const FieldFilter F = NameFilter("F");
const FieldFilter G = NameFilter("G");
const FieldFilter H = NameFilter("H");
const FieldFilter I = NameFilter("I");

}  // namespace

class LogicUtilsTest : public ::testing::Test, public LogicUtils {
 public:
  using LogicUtils::ApplyAssociation;

  LogicUtilsTest() {
  }
};

TEST_F(LogicUtilsTest, FieldFilterAssociativity) {
  FieldFilter filter = testutil::Filter("foo", "==", "bar");
  EXPECT_EQ(filter, ApplyAssociation(filter));
}

TEST_F(LogicUtilsTest, CompositeFilterAssociativity) {
  // AND(AND(X)) --> X
  CompositeFilter composite_filter1 = AndFilters({AndFilters({A})});
  EXPECT_EQ(A, ApplyAssociation(composite_filter1));

  // OR(OR(X)) --> X
  CompositeFilter composite_filter2 = OrFilters({OrFilters({A})});
  EXPECT_EQ(A, ApplyAssociation(composite_filter2));

  // (A | (B) | ((C) | (D | E)) | (F | (G & (H & I)))
  // --> A | B | C | D | E | F | (G & H & I)
  CompositeFilter complex_filter = OrFilters(
      {A, AndFilters({B}), OrFilters({OrFilters({C}), OrFilters({D, E})}),
       OrFilters({F, AndFilters({G, AndFilters({H, I})})})});
  CompositeFilter expected_result =
      OrFilters({A, B, C, D, E, F, AndFilters({G, H, I})});
  EXPECT_EQ(ApplyAssociation(complex_filter), expected_result);
}

TEST_F(LogicUtilsTest, FieldFilterDistributionOverFieldFilter) {
  EXPECT_EQ(ApplyDistribution(A, B), AndFilters({A, B}));
  EXPECT_EQ(ApplyDistribution(B, A), AndFilters({B, A}));
}

TEST_F(LogicUtilsTest, FieldFilterDistributionOverAndFilter) {
  // (A & B & C) & D = (A & B & C & D)
  EXPECT_EQ(ApplyDistribution(AndFilters({A, B, C}), D),
            AndFilters({A, B, C, D}));
}

TEST_F(LogicUtilsTest, FieldFilterDistributionOverOrFilter) {
  // A & (B | C | D) = (A & B) | (A & C) | (A & D)
  // (B | C | D) & A = (A & B) | (A & C) | (A & D)
  CompositeFilter expected =
      OrFilters({AndFilters({A, B}), AndFilters({A, C}), AndFilters({A, D})});
  EXPECT_EQ(ApplyDistribution(A, OrFilters({B, C, D})), expected);
  EXPECT_EQ(ApplyDistribution(OrFilters({B, C, D}), A), expected);
}

// The following four tests cover:
// AND distribution for AND filter and AND filter.
// AND distribution for OR filter and AND filter.
// AND distribution for AND filter and OR filter.
// AND distribution for OR filter and OR filter.
TEST_F(LogicUtilsTest, AndFilterDistributionWithAndFilter) {
  // (A & B) & (C & D) --> (A & B & C & D)
  CompositeFilter expected = AndFilters({A, B, C, D});
  EXPECT_EQ(ApplyDistribution((core::Filter)AndFilters({A, B}),
                              (core::Filter)AndFilters({C, D})),
            expected);
}

TEST_F(LogicUtilsTest, AndFilterDistributionWithOrFilter) {
  // (A & B) & (C | D) --> (A & B & C) | (A & B & D)
  CompositeFilter expected =
      OrFilters({AndFilters({A, B, C}), AndFilters({A, B, D})});
  EXPECT_EQ(ApplyDistribution((core::Filter)AndFilters({A, B}),
                              (core::Filter)OrFilters({C, D})),
            expected);
}

TEST_F(LogicUtilsTest, OrFilterDistributionWithAndFilter) {
  // (A | B) & (C & D) --> (A & C & D) | (B & C & D)
  CompositeFilter expected =
      OrFilters({AndFilters({C, D, A}), AndFilters({C, D, B})});
  EXPECT_EQ(ApplyDistribution((core::Filter)OrFilters({A, B}),
                              (core::Filter)AndFilters({C, D})),
            expected);
}

TEST_F(LogicUtilsTest, OrFilterDistributionWithOrFilter) {
  // (A | B) & (C | D) --> (A & C) | (A & D) | (B & C) | (B & D)
  CompositeFilter expected =
      OrFilters({AndFilters({A, C}), AndFilters({A, D}), AndFilters({B, C}),
                 AndFilters({B, D})});
  EXPECT_EQ(ApplyDistribution((core::Filter)OrFilters({A, B}),
                              (core::Filter)OrFilters({C, D})),
            expected);
}

TEST_F(LogicUtilsTest, FieldFilterComputeDnf) {
  EXPECT_EQ(ComputeDistributedNormalForm(A), A);
  EXPECT_EQ(GetDnfTerms(AndFilters({A})), std::vector<core::Filter>{A});
  EXPECT_EQ(GetDnfTerms(OrFilters({A})), std::vector<core::Filter>{A});
}

TEST_F(LogicUtilsTest, ComputeDnfFlatAndFilter) {
  CompositeFilter composite_filter = AndFilters({A, B, C});
  EXPECT_EQ(ComputeDistributedNormalForm(composite_filter), composite_filter);
  EXPECT_EQ(GetDnfTerms(composite_filter),
            std::vector<core::Filter>{composite_filter});
}

TEST_F(LogicUtilsTest, ComputeDnfFlatOrFilter) {
  CompositeFilter composite_filter = OrFilters({A, B, C});
  EXPECT_EQ(ComputeDistributedNormalForm(composite_filter), composite_filter);
  std::vector<core::Filter> expected_dnf_terms{A, B, C};
  EXPECT_EQ(GetDnfTerms(composite_filter),
            std::vector<core::Filter>{expected_dnf_terms});
}

TEST_F(LogicUtilsTest, ComputeDnf1) {
  // A & (B | C) --> (A & B) | (A & C)
  CompositeFilter composite_filter = AndFilters({A, OrFilters({B, C})});
  std::vector<core::Filter> expected_dnf_terms{AndFilters({A, B}),
                                               AndFilters({A, C})};
  CompositeFilter expected = OrFilters(expected_dnf_terms);
  EXPECT_EQ(ComputeDistributedNormalForm(composite_filter), expected);
  EXPECT_EQ(GetDnfTerms(composite_filter),
            std::vector<core::Filter>{expected_dnf_terms});
}

TEST_F(LogicUtilsTest, ComputeDnf2) {
  // ((A)) & (B & C) --> A & B & C
  CompositeFilter composite_filter =
      AndFilters({AndFilters({AndFilters({A})}), AndFilters({B, C})});
  CompositeFilter expected = AndFilters({A, B, C});
  EXPECT_EQ(ComputeDistributedNormalForm(composite_filter), expected);
  EXPECT_EQ(GetDnfTerms(composite_filter), std::vector<core::Filter>{expected});
}

TEST_F(LogicUtilsTest, ComputeDnf3) {
  // A | (B & C)
  CompositeFilter composite_filter = OrFilters({A, AndFilters({B, C})});
  EXPECT_EQ(ComputeDistributedNormalForm(composite_filter), composite_filter);
  std::vector<core::Filter> expected_dnf_terms{A, AndFilters({B, C})};
  EXPECT_EQ(GetDnfTerms(composite_filter),
            std::vector<core::Filter>{expected_dnf_terms});
}

TEST_F(LogicUtilsTest, ComputeDnf4) {
  // A | (B & C) | ( ((D)) | (E | F) | (G & H) ) --> A | (B & C) | D | E | F |
  // (G & H)
  CompositeFilter composite_filter =
      OrFilters({A, AndFilters({B, C}),
                 OrFilters({AndFilters({OrFilters({D})}), OrFilters({E, F}),
                            AndFilters({G, H})})});
  std::vector<core::Filter> expected_dnf_terms{A, AndFilters({B, C}), D, E,
                                               F, AndFilters({G, H})};
  CompositeFilter expected = OrFilters({expected_dnf_terms});
  EXPECT_EQ(ComputeDistributedNormalForm(composite_filter), expected);
  EXPECT_EQ(GetDnfTerms(composite_filter),
            std::vector<core::Filter>{expected_dnf_terms});
}

TEST_F(LogicUtilsTest, ComputeDnf5) {
  //    A & (B | C) & ( ((D)) & (E | F) & (G & H) )
  // -> A & (B | C) & D & (E | F) & G & H
  // -> ((A & B) | (A & C)) & D & (E | F) & G & H
  // -> ((A & B & D) | (A & C & D)) & (E|F) & G & H
  // -> ((A & B & D & E) | (A & B & D & F) | (A & C & D & E) | (A & C & D & F))
  // & G & H
  // -> ((A&B&D&E&G) | (A & B & D & F & G) | (A & C & D & E & G) | (A & C & D &
  // F & G)) & H
  // -> (A&B&D&E&G&H) | (A&B&D&F&G&H) | (A & C & D & E & G & H) | (A & C & D & F
  // & G & H)
  CompositeFilter composite_filter =
      AndFilters({A, OrFilters({B, C}),
                  AndFilters({AndFilters({OrFilters({D})}), OrFilters({E, F}),
                              AndFilters({G, H})})});
  std::vector<core::Filter> expected_dnf_terms{
      AndFilters({D, E, G, H, A, B}), AndFilters({D, F, G, H, A, B}),
      AndFilters({D, E, G, H, A, C}), AndFilters({D, F, G, H, A, C})};
  CompositeFilter expected = OrFilters({expected_dnf_terms});
  EXPECT_EQ(ComputeDistributedNormalForm(composite_filter), expected);
  EXPECT_EQ(GetDnfTerms(composite_filter),
            std::vector<core::Filter>{expected_dnf_terms});
}

TEST_F(LogicUtilsTest, ComputeDnf6) {
  // A & (B | (C & (D | (E & F))))
  // -> A & (B | (C & D) | (C & E & F))
  // -> (A & B) | (A & C & D) | (A & C & E & F)
  CompositeFilter composite_filter = AndFilters(
      {A, OrFilters({B, AndFilters({C, OrFilters({D, AndFilters({E, F})})})})});
  std::vector<core::Filter> expected_dnf_terms{
      AndFilters({A, B}), AndFilters({C, D, A}), AndFilters({E, F, C, A})};
  CompositeFilter expected = OrFilters({expected_dnf_terms});
  EXPECT_EQ(ComputeDistributedNormalForm(composite_filter), expected);
  EXPECT_EQ(GetDnfTerms(composite_filter),
            std::vector<core::Filter>{expected_dnf_terms});
}

TEST_F(LogicUtilsTest, ComputeDnf7) {
  // ( (A|B) & (C|D) ) | ( (E|F) & (G|H) )
  // -> (A&C)|(A&D)|(B&C)(B&D)|(E&G)|(E&H)|(F&G)|(F&H)
  CompositeFilter composite_filter =
      OrFilters({AndFilters({OrFilters({A, B}), OrFilters({C, D})}),
                 AndFilters({OrFilters({E, F}), OrFilters({G, H})})});
  std::vector<core::Filter> expected_dnf_terms{
      AndFilters({A, C}), AndFilters({A, D}), AndFilters({B, C}),
      AndFilters({B, D}), AndFilters({E, G}), AndFilters({E, H}),
      AndFilters({F, G}), AndFilters({F, H})};
  CompositeFilter expected = OrFilters({expected_dnf_terms});
  EXPECT_EQ(ComputeDistributedNormalForm(composite_filter), expected);
  EXPECT_EQ(GetDnfTerms(composite_filter),
            std::vector<core::Filter>{expected_dnf_terms});
}

TEST_F(LogicUtilsTest, ComputeDnf8) {
  // ( (A&B) | (C&D) ) & ( (E&F) | (G&H) )
  // -> A&B&E&F | A&B&G&H | C&D&E&F | C&D&G&H
  CompositeFilter composite_filter =
      AndFilters({OrFilters({AndFilters({A, B}), AndFilters({C, D})}),
                  OrFilters({AndFilters({E, F}), AndFilters({G, H})})});
  std::vector<core::Filter> expected_dnf_terms{
      AndFilters({E, F, A, B}), AndFilters({G, H, A, B}),
      AndFilters({E, F, C, D}), AndFilters({G, H, C, D})};
  CompositeFilter expected = OrFilters({expected_dnf_terms});
  EXPECT_EQ(ComputeDistributedNormalForm(composite_filter), expected);
  EXPECT_EQ(GetDnfTerms(composite_filter),
            std::vector<core::Filter>{expected_dnf_terms});
}

TEST_F(LogicUtilsTest, InExpansionForFieldFilters) {
  auto input1 = testutil::Filter("a", "in", Array(1, 2, 3));
  auto input2 = testutil::Filter("a", "<", 1);
  auto input3 = testutil::Filter("a", "<=", 1);
  auto input4 = testutil::Filter("a", "==", 1);
  auto input5 = testutil::Filter("a", "!=", 1);
  auto input6 = testutil::Filter("a", ">", 1);
  auto input7 = testutil::Filter("a", ">=", 1);
  auto input8 = testutil::Filter("a", "array-contains", 1);
  auto input9 = testutil::Filter("a", "array-contains-any", Array(1, 2));
  auto input10 = testutil::Filter("a", "not-in", Array(1, 2));

  EXPECT_EQ(
      ComputeInExpansion(input1),
      OrFilters({testutil::Filter("a", "==", 1), testutil::Filter("a", "==", 2),
                 testutil::Filter("a", "==", 3)}));

  // Other operators should remain the same
  EXPECT_EQ(ComputeInExpansion(input2), input2);
  EXPECT_EQ(ComputeInExpansion(input3), input3);
  EXPECT_EQ(ComputeInExpansion(input4), input4);
  EXPECT_EQ(ComputeInExpansion(input5), input5);
  EXPECT_EQ(ComputeInExpansion(input6), input6);
  EXPECT_EQ(ComputeInExpansion(input7), input7);
  EXPECT_EQ(ComputeInExpansion(input8), input8);
  EXPECT_EQ(ComputeInExpansion(input9), input9);
  EXPECT_EQ(ComputeInExpansion(input10), input10);
}

TEST_F(LogicUtilsTest, InExpansionForCompositeFilters) {
  auto cf1 = AndFilters({testutil::Filter("a", "==", 1),
                         testutil::Filter("b", "in", Array(2, 3, 4))});
  EXPECT_EQ(ComputeInExpansion(cf1),
            AndFilters({testutil::Filter("a", "==", 1),
                        OrFilters({testutil::Filter("b", "==", 2),
                                   testutil::Filter("b", "==", 3),
                                   testutil::Filter("b", "==", 4)})}));

  auto cf2 = OrFilters({testutil::Filter("a", "==", 1),
                        testutil::Filter("b", "in", Array(2, 3, 4))});
  EXPECT_EQ(ComputeInExpansion(cf2),
            OrFilters({testutil::Filter("a", "==", 1),
                       OrFilters({testutil::Filter("b", "==", 2),
                                  testutil::Filter("b", "==", 3),
                                  testutil::Filter("b", "==", 4)})}));

  auto cf3 =
      AndFilters({testutil::Filter("a", "==", 1),
                  OrFilters({testutil::Filter("b", "==", 2),
                             testutil::Filter("c", "in", Array(2, 3, 4))})});
  EXPECT_EQ(
      ComputeInExpansion(cf3),
      AndFilters({testutil::Filter("a", "==", 1),
                  OrFilters({testutil::Filter("b", "==", 2),
                             OrFilters({testutil::Filter("c", "==", 2),
                                        testutil::Filter("c", "==", 3),
                                        testutil::Filter("c", "==", 4)})})}));

  CompositeFilter cf4 =
      OrFilters({testutil::Filter("a", "==", 1),
                 AndFilters({testutil::Filter("b", "==", 2),
                             testutil::Filter("c", "in", Array(2, 3, 4))})});
  EXPECT_EQ(
      ComputeInExpansion(cf4),
      OrFilters({testutil::Filter("a", "==", 1),
                 AndFilters({testutil::Filter("b", "==", 2),
                             OrFilters({testutil::Filter("c", "==", 2),
                                        testutil::Filter("c", "==", 3),
                                        testutil::Filter("c", "==", 4)})})}));
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
