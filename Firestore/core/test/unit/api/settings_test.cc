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
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/api/settings.h"
#include "Firestore/core/src/credentials/empty_credentials_provider.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/remote/firebase_metadata_provider.h"
#include "Firestore/core/src/util/async_queue.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace api {
namespace {

using ::testing::HasSubstr;

std::shared_ptr<Firestore> MakeTestFirestore() {
  return std::make_shared<Firestore>(
      model::DatabaseId("project", "(default)"), "persistence-key",
      std::make_shared<credentials::EmptyAuthCredentialsProvider>(),
      std::make_shared<credentials::EmptyAppCheckCredentialsProvider>(),
      /*worker_queue=*/nullptr,
      /*firebase_metadata_provider=*/nullptr,
      /*extension=*/nullptr);
}

void ExpectSslDisabledRejectedAsIllegalState(const std::string& host) {
  auto db = MakeTestFirestore();
  Settings settings;
  settings.set_host(host);
  settings.set_ssl_enabled(false);
  try {
    db->set_settings(settings);
    ADD_FAILURE() << "Expected set_settings to reject ssl_enabled=false for '"
                  << host << "'";
  } catch (const std::invalid_argument& e) {
    ADD_FAILURE() << "Expected IllegalState (logic_error), got "
                     "InvalidArgument for '"
                  << host << "': " << e.what();
  } catch (const std::logic_error& e) {
    EXPECT_THAT(e.what(),
                HasSubstr("You can't set the 'sslEnabled' setting to false"));
  }
}

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

TEST(Settings, DisablingSslOnDefaultHostVariantsThrowsIllegalState) {
  const std::vector<std::string> default_host_variants = {
      "firestore.googleapis.com",      "firestore.googleapis.com:443",
      "firestore.googleapis.com:8080", "Firestore.GoogleAPIs.com",
      "FIRESTORE.GOOGLEAPIS.COM:443",  "firestore.googleapis.com.",
      "firestore.googleapis.com.:443", "firestore.googleapis.com...",
  };
  for (const std::string& host : default_host_variants) {
    Settings settings;
    settings.set_host(host);
    EXPECT_TRUE(settings.IsDefaultHost()) << "host: " << host;
    ExpectSslDisabledRejectedAsIllegalState(host);
  }

  const std::vector<std::string> non_default_hosts = {
      "localhost",
      "localhost:8080",
      "127.0.0.1:8080",
      "[::1]:8080",
      "myfirestore.googleapis.com",
      "firestore.googleapis.com.example.com",
  };
  for (const std::string& host : non_default_hosts) {
    auto db = MakeTestFirestore();
    Settings settings;
    settings.set_host(host);
    EXPECT_FALSE(settings.IsDefaultHost()) << "host: " << host;
    settings.set_ssl_enabled(false);
    EXPECT_NO_THROW(db->set_settings(settings)) << "host: " << host;
  }
}

TEST(Settings, RejectsMalformedAndUriSchemeHosts) {
  const std::vector<std::string> invalid_hosts = {
      "",
      "dns://8.8.8.8/firestore.googleapis.com:443",
      "dns:///firestore.googleapis.com",
      "unix:/tmp/firestore.sock",
      "unix-abstract:firestore",
      "ipv4:127.0.0.1:8080",
      "ipv6:[::1]:8080",
      "https://firestore.googleapis.com",
      "http://localhost:8080",
      "firestore.googleapis.com/path",
      "user@firestore.googleapis.com",
      "localhost:0",
      "localhost:65536",
      "localhost:notaport",
      "0177.0.0.1:8080",
      "::1",
      "::1:8080",
      "[::1",
      "b\xc3\xbc"
      "cher.example",
  };
  for (const std::string& host : invalid_hosts) {
    auto db = MakeTestFirestore();
    Settings settings;
    settings.set_host(host);
    EXPECT_THROW(db->set_settings(settings), std::invalid_argument)
        << "host: '" << host << "'";
  }

  const std::vector<std::string> valid_hosts = {
      "firestore.googleapis.com", "firestore.googleapis.com:443",
      "localhost:8080",           "10.0.2.2:8080",
      "127.0.0.1:8080",           "[::1]:8080",
  };
  for (const std::string& host : valid_hosts) {
    auto db = MakeTestFirestore();
    Settings settings;
    settings.set_host(host);
    EXPECT_NO_THROW(db->set_settings(settings)) << "host: '" << host << "'";
  }
}

}  // namespace

}  // namespace api
}  // namespace firestore
}  // namespace firebase
