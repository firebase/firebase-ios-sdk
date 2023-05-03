/*
 * Copyright 2023 Google LLC
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

#include <memory>
#include <string>
#include <utility>

#include "Firestore/core/src/api/settings.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace api {
namespace {

TEST(Settings, CopyConstructor) {
  {
    Settings settings;
    settings.set_host("host");
    settings.set_ssl_enabled(true);
    settings.set_persistence_enabled(true);
    settings.set_cache_size_bytes(100);

    Settings copy(settings);

    EXPECT_EQ(settings.host(), copy.host());
    EXPECT_EQ(settings.ssl_enabled(), copy.ssl_enabled());
    EXPECT_EQ(settings.persistence_enabled(), copy.persistence_enabled());
    EXPECT_EQ(settings.cache_size_bytes(), copy.cache_size_bytes());
    EXPECT_EQ(settings.local_cache_settings(), copy.local_cache_settings());
  }
  {
    Settings settings;
    settings.set_host("host");
    settings.set_ssl_enabled(true);
    settings.set_local_cache_settings(MemoryCacheSettings{});

    Settings copy(settings);

    EXPECT_EQ(settings.host(), copy.host());
    EXPECT_EQ(settings.ssl_enabled(), copy.ssl_enabled());
    EXPECT_EQ(settings.persistence_enabled(), copy.persistence_enabled());
    EXPECT_EQ(settings.cache_size_bytes(), copy.cache_size_bytes());
    EXPECT_EQ(*(settings.local_cache_settings()),
              *(copy.local_cache_settings()));
  }
  {
    Settings settings;
    settings.set_host("host");
    settings.set_ssl_enabled(false);
    settings.set_local_cache_settings(
        PersistentCacheSettings{}.WithSizeBytes(1000000));

    Settings copy(settings);

    EXPECT_EQ(settings.host(), copy.host());
    EXPECT_EQ(settings.ssl_enabled(), copy.ssl_enabled());
    EXPECT_EQ(settings.persistence_enabled(), copy.persistence_enabled());
    EXPECT_EQ(settings.cache_size_bytes(), copy.cache_size_bytes());
    EXPECT_EQ(*(settings.local_cache_settings()),
              *(copy.local_cache_settings()));
  }
}

TEST(Settings, MoveConstructor) {
  Settings settings;
  settings.set_host("host");
  settings.set_ssl_enabled(true);
  settings.set_persistence_enabled(true);
  settings.set_cache_size_bytes(100);

  Settings copy(settings);
  Settings move(std::move(settings));

  EXPECT_EQ(copy, move);
  EXPECT_EQ("", settings.host());
  EXPECT_EQ(true, settings.ssl_enabled());
  EXPECT_EQ(true, settings.persistence_enabled());
  EXPECT_EQ(copy.cache_size_bytes(), settings.cache_size_bytes());
  EXPECT_EQ(nullptr, settings.local_cache_settings());
}

TEST(Settings, CopyAssignmentOperator) {
  Settings settings;
  settings.set_host("host");
  settings.set_ssl_enabled(true);
  settings.set_local_cache_settings(
      PersistentCacheSettings{}.WithSizeBytes(1000000));

  Settings other;
  other = settings;

  EXPECT_EQ(settings.host(), other.host());
  EXPECT_EQ(settings.ssl_enabled(), other.ssl_enabled());
  EXPECT_EQ(settings.persistence_enabled(), other.persistence_enabled());
  EXPECT_EQ(settings.cache_size_bytes(), other.cache_size_bytes());
  EXPECT_EQ(*(settings.local_cache_settings()),
            *(other.local_cache_settings()));
}

TEST(Settings, MoveAssignmentOperator) {
  Settings settings;
  settings.set_host("host");
  settings.set_ssl_enabled(true);
  settings.set_local_cache_settings(
      PersistentCacheSettings{}.WithSizeBytes(1000000));

  Settings copy = settings;
  Settings other;
  other = std::move(settings);

  EXPECT_EQ(copy, other);
  EXPECT_NO_FATAL_FAILURE(settings.persistence_enabled());
  EXPECT_NO_FATAL_FAILURE(settings.local_cache_settings());
}

TEST(Settings, EqualityAndHash) {
  {
    Settings settings1;
    settings1.set_host("host");
    settings1.set_ssl_enabled(false);
    settings1.set_persistence_enabled(true);
    settings1.set_cache_size_bytes(100);

    Settings settings2;
    settings2.set_host("host");
    settings2.set_ssl_enabled(false);
    settings2.set_persistence_enabled(true);
    settings2.set_cache_size_bytes(100);

    EXPECT_EQ(settings1, settings2);
    EXPECT_EQ(settings1.Hash(), settings2.Hash());

    settings2.set_host("other_host");

    EXPECT_NE(settings1, settings2);
    EXPECT_NE(settings1.Hash(), settings2.Hash());
  }
  {
    Settings settings1;
    settings1.set_host("host");
    settings1.set_ssl_enabled(false);
    settings1.set_local_cache_settings(MemoryCacheSettings{});

    Settings settings2;
    settings2.set_host("host");
    settings2.set_ssl_enabled(false);
    settings2.set_local_cache_settings(MemoryCacheSettings{});

    EXPECT_EQ(settings1, settings2);
    EXPECT_EQ(settings1.Hash(), settings2.Hash());

    settings2.set_local_cache_settings(PersistentCacheSettings{});

    EXPECT_NE(settings1, settings2);
    EXPECT_NE(settings1.Hash(), settings2.Hash());
  }
  {
    Settings settings1;
    settings1.set_host("host");
    settings1.set_ssl_enabled(true);
    settings1.set_local_cache_settings(
        PersistentCacheSettings{}.WithSizeBytes(1000000));

    Settings settings2;
    settings2.set_host("host");
    settings2.set_ssl_enabled(true);
    settings2.set_local_cache_settings(
        PersistentCacheSettings{}.WithSizeBytes(2000000));

    EXPECT_NE(settings1, settings2);
    EXPECT_NE(settings1.Hash(), settings2.Hash());
  }
}

}  // namespace

}  // namespace api
}  // namespace firestore
}  // namespace firebase
