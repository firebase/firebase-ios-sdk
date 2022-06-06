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

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <iostream>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/api/collection_reference.h"
#include "Firestore/core/src/api/document_reference.h"
#include "Firestore/core/src/api/settings.h"
#include "Firestore/core/src/core/user_data.h"
#include "Firestore/core/src/credentials/credentials_provider.h"
#include "Firestore/core/src/credentials/empty_credentials_provider.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/object_value.h"
#include "Firestore/core/src/remote/firebase_metadata_provider.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/executor.h"
#include "Firestore/core/src/util/status.h"
#include "absl/memory/memory.h"

using firebase::firestore::google_firestore_v1_Value;
using firebase::firestore::api::Firestore;
using firebase::firestore::api::Settings;
using firebase::firestore::core::ParsedSetData;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::nanopb::Message;
using firebase::firestore::credentials::EmptyAppCheckCredentialsProvider;
using firebase::firestore::credentials::EmptyAuthCredentialsProvider;
using firebase::firestore::remote::FirebaseMetadataProvider;
using firebase::firestore::util::AsyncQueue;
using firebase::firestore::util::Executor;
using firebase::firestore::util::Status;

class EmptyFirebaseMetadataProvider : public FirebaseMetadataProvider {
 public:
  void UpdateMetadata(grpc::ClientContext&) override {
  }
};

void Log(const std::string& s) {
  std::cout << s << std::endl;
}

void Log(const std::string& s1, const std::string& s2) {
  std::cout << s1 << s2 << std::endl;
}

int RunTest() {
  Log("Firestore::SetClientLanguage()");
  Firestore::SetClientLanguage("gl-objc/");

  Log("Creating arguments for Firestore constructor");
  std::shared_ptr<AsyncQueue> worker_queue = AsyncQueue::Create(Executor::CreateSerial("zzyzx-worker"));
  auto auth_credentials_provider = std::make_shared<EmptyAuthCredentialsProvider>();
  auto app_check_credentials_provider = std::make_shared<EmptyAppCheckCredentialsProvider>();
  auto firebase_metadata_provider = absl::make_unique<EmptyFirebaseMetadataProvider>();
  DatabaseId database_id("dconeybe-testing", "(default)");
  std::string persistence_key = "denver";

  Log("std::make_shared<Firestore>()");
  auto firestore = std::make_shared<Firestore>(
      std::move(database_id),
      std::move(persistence_key),
      auth_credentials_provider,
      app_check_credentials_provider,
      worker_queue,
      std::move(firebase_metadata_provider),
      nullptr);
  new std::shared_ptr<Firestore>(firestore->shared_from_this());

  firestore->set_user_executor(Executor::CreateSerial("zzyzx-user"));

  Log("firestore->set_settings(settings)");
  Settings settings;
  settings.set_host("localhost:8080");
  settings.set_ssl_enabled(false);
  firestore->set_settings(settings);

  FieldPath field_path(std::vector<std::string>{"value"});
  Message<google_firestore_v1_Value> value;
  value->which_value_type = google_firestore_v1_Value_integer_value_tag;
  value->integer_value = 42;
  ObjectValue object_value;
  object_value.Set(field_path, std::move(value));
  ParsedSetData parsed_set_data(std::move(object_value), {});

  auto collection = firestore->GetCollection("denver");
  auto doc = collection.Document();
  Log("Writing data to: ", doc.Path());
  auto done_flag = new std::atomic_bool;
  done_flag->store(false);
  auto* mutex = new std::mutex;
  auto* cv = new std::condition_variable;
  doc.SetData(std::move(parsed_set_data), [mutex, cv, done_flag](Status status) {
    std::unique_lock<std::mutex> lock(*mutex);
    done_flag->store(true);
    Log("SetData() completed: ", status.ToString());
    cv->notify_all();
  });

  {
    std::unique_lock<std::mutex> lock(*mutex);
    Log("Waiting for SetData() to complete");
    cv->wait(lock, [done_flag]() { return done_flag->load(); });
    Log("Waiting for SetData() to complete DONE!");
  }

  Log("Success!!!!");
  return 0;
}

int main(int, char**) {
  std::thread t(RunTest);
  t.detach();

  for (int i=0; i<500; i++) {
    std::this_thread::yield();
  }

  return 0;
}
