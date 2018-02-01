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

#include "Firestore/core/src/firebase/firestore/model/base_path.h"

#include <initializer_list>
#include <string>
#include <vector>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

// A simple struct to be able to instantiate BasePath.
struct Path : impl::BasePath<Path> {
  Path() = default;
  template <typename IterT>
  Path(const IterT begin, const IterT end) : BasePath{begin, end} {
  }
  Path(std::initializer_list<std::string> list) : BasePath{list} {
  }
  Path(SegmentsT&& segments) : BasePath{std::move(segments)} {}

  bool operator==(const Path& rhs) const {
    return BasePath::operator==(rhs);
  }
  bool operator!=(const Path& rhs) const {
    return BasePath::operator!=(rhs);
  }
};

TEST(BasePath, Constructor) {
  const Path empty_path;
  EXPECT_TRUE(empty_path.empty());
  EXPECT_EQ(0, empty_path.size());
  EXPECT_TRUE(empty_path.begin() == empty_path.end());

  const Path path_from_list{{"rooms", "Eros", "messages"}};
  EXPECT_FALSE(path_from_list.empty());
  EXPECT_EQ(3, path_from_list.size());
  EXPECT_TRUE(path_from_list.begin() + 3 == path_from_list.end());

  std::vector<std::string> segments{"rooms", "Eros", "messages"};
  const Path path_from_segments{segments.begin(), segments.end()};
  EXPECT_FALSE(path_from_segments.empty());
  EXPECT_EQ(3, path_from_segments.size());
  EXPECT_TRUE(path_from_segments.begin() + 3 == path_from_segments.end());
}

TEST(BasePath, Indexing) {
  const Path path{{"rooms", "Eros", "messages"}};

  EXPECT_EQ(path.front(), "rooms");
  EXPECT_EQ(path[0], "rooms");
  EXPECT_EQ(path.at(0), "rooms");

  EXPECT_EQ(path[1], "Eros");
  EXPECT_EQ(path.at(1), "Eros");

  EXPECT_EQ(path[2], "messages");
  EXPECT_EQ(path.at(2), "messages");
  EXPECT_EQ(path.back(), "messages");
}

TEST(BasePath, WithoutFirst) {
  const Path abc{"rooms", "Eros", "messages"};
  const Path bc{"Eros", "messages"};
  const Path c{"messages"};
  const Path empty;
  const Path abc_dupl{"rooms", "Eros", "messages"};

  EXPECT_NE(empty, c);
  EXPECT_NE(c, bc);
  EXPECT_NE(bc, abc);

  EXPECT_EQ(bc, abc.WithoutFirstElement());
  EXPECT_EQ(c, abc.WithoutFirstElements(2));
  EXPECT_EQ(empty, abc.WithoutFirstElements(3));
  EXPECT_EQ(abc_dupl, abc);
}

TEST(BasePath, WithoutLast) {
  const Path abc{"rooms", "Eros", "messages"};
  const Path ab{"rooms", "Eros"};
  const Path a{"rooms"};
  const Path empty;
  const Path abc_dupl{"rooms", "Eros", "messages"};

  EXPECT_EQ(ab, abc.WithoutLastElement());
  EXPECT_EQ(a, abc.WithoutLastElement().WithoutLastElement());
  EXPECT_EQ(empty,
            abc.WithoutLastElement().WithoutLastElement().WithoutLastElement());
}

TEST(BasePath, Concatenation) {
  const Path path;
  const Path a{"rooms"};
  const Path ab{"rooms", "Eros"};
  const Path abc{"rooms", "Eros", "messages"};

  EXPECT_EQ(a, path.Concatenated("rooms"));
  EXPECT_EQ(ab, path.Concatenated("rooms").Concatenated("Eros"));
  EXPECT_EQ(abc, path.Concatenated("rooms").Concatenated("Eros").Concatenated("messages"));
  EXPECT_EQ(abc, path.Concatenated(Path{"rooms", "Eros", "messages"}));
}

// Concatenated
// <
// isPrefixOf

// throws on invalid
// canonical string
// --//-- of substr?

}  // namespace model
}  // namespace firestore
}  // namespace firebase
