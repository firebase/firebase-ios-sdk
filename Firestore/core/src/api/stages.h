/*
 * Copyright 2025 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_API_STAGES_H_
#define FIRESTORE_CORE_SRC_API_STAGES_H_

#include <memory>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/api/aggregate_expressions.h"
#include "Firestore/core/src/api/api_fwd.h"
#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/ordering.h"
#include "Firestore/core/src/nanopb/message.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace api {

class Stage {
 public:
  Stage() = default;
  virtual ~Stage() = default;

  virtual google_firestore_v1_Pipeline_Stage to_proto() const = 0;
};

class CollectionSource : public Stage {
 public:
  explicit CollectionSource(std::string path) : path_(std::move(path)) {
  }
  ~CollectionSource() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::string path_;
};

class DatabaseSource : public Stage {
 public:
  DatabaseSource() = default;
  ~DatabaseSource() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;
};

class CollectionGroupSource : public Stage {
 public:
  explicit CollectionGroupSource(std::string collection_id)
      : collection_id_(std::move(collection_id)) {
  }
  ~CollectionGroupSource() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::string collection_id_;
};

class DocumentsSource : public Stage {
 public:
  explicit DocumentsSource(std::vector<std::string> documents)
      : documents_(std::move(documents)) {
  }
  ~DocumentsSource() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::vector<std::string> documents_;
};

class AddFields : public Stage {
 public:
  explicit AddFields(
      std::unordered_map<std::string, std::shared_ptr<Expr>> fields)
      : fields_(std::move(fields)) {
  }
  ~AddFields() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::unordered_map<std::string, std::shared_ptr<Expr>> fields_;
};

class AggregateStage : public Stage {
 public:
  AggregateStage(
      std::unordered_map<std::string, std::shared_ptr<AggregateFunction>>
          accumulators,
      std::unordered_map<std::string, std::shared_ptr<Expr>> groups)
      : accumulators_(std::move(accumulators)), groups_(std::move(groups)) {
  }

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::unordered_map<std::string, std::shared_ptr<AggregateFunction>>
      accumulators_;
  std::unordered_map<std::string, std::shared_ptr<Expr>> groups_;
};

class Where : public Stage {
 public:
  explicit Where(std::shared_ptr<Expr> expr) : expr_(expr) {
  }
  ~Where() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::shared_ptr<Expr> expr_;
};

class FindNearestStage : public Stage {
 public:
  class DistanceMeasure {
   public:
    enum Measure { EUCLIDEAN, COSINE, DOT_PRODUCT };

    explicit DistanceMeasure(Measure measure) : measure_(measure) {
    }
    google_firestore_v1_Value proto() const;

   private:
    Measure measure_;
  };

  FindNearestStage(
      std::shared_ptr<Expr> property,
      nanopb::SharedMessage<google_firestore_v1_Value> vector,
      DistanceMeasure distance_measure,
      std::unordered_map<std::string,
                         nanopb::SharedMessage<google_firestore_v1_Value>>
          options)
      : property_(std::move(property)),
        vector_(std::move(vector)),
        distance_measure_(distance_measure),
        options_(options) {
  }

  ~FindNearestStage() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::shared_ptr<Expr> property_;
  nanopb::SharedMessage<google_firestore_v1_Value> vector_;
  DistanceMeasure distance_measure_;
  std::unordered_map<std::string,
                     nanopb::SharedMessage<google_firestore_v1_Value>>
      options_;
};

class LimitStage : public Stage {
 public:
  explicit LimitStage(int32_t limit) : limit_(limit) {
  }
  ~LimitStage() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  int32_t limit_;
};

class OffsetStage : public Stage {
 public:
  explicit OffsetStage(int64_t offset) : offset_(offset) {
  }
  ~OffsetStage() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  int64_t offset_;
};

class SelectStage : public Stage {
 public:
  explicit SelectStage(
      std::unordered_map<std::string, std::shared_ptr<Expr>> fields)
      : fields_(std::move(fields)) {
  }
  ~SelectStage() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::unordered_map<std::string, std::shared_ptr<Expr>> fields_;
};

class SortStage : public Stage {
 public:
  explicit SortStage(std::vector<std::shared_ptr<Ordering>> orders)
      : orders_(std::move(orders)) {
  }
  ~SortStage() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::vector<std::shared_ptr<Ordering>> orders_;
};

class DistinctStage : public Stage {
 public:
  explicit DistinctStage(
      std::unordered_map<std::string, std::shared_ptr<Expr>> groups)
      : groups_(std::move(groups)) {
  }
  ~DistinctStage() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::unordered_map<std::string, std::shared_ptr<Expr>> groups_;
};

class RemoveFieldsStage : public Stage {
 public:
  explicit RemoveFieldsStage(std::vector<Field> fields)
      : fields_(std::move(fields)) {
  }
  ~RemoveFieldsStage() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::vector<Field> fields_;
};

class ReplaceWith : public Stage {
 public:
  explicit ReplaceWith(std::shared_ptr<Expr> expr);
  ~ReplaceWith() override = default;
  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::shared_ptr<Expr> expr_;
};

class Sample : public Stage {
 public:
  Sample(std::string type, int64_t count, double percentage);
  ~Sample() override = default;
  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::string type_;
  int64_t count_;
  double percentage_;
};

class Union : public Stage {
 public:
  explicit Union(std::shared_ptr<Pipeline> other);
  ~Union() override = default;
  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::shared_ptr<Pipeline> other_;
};

class Unnest : public Stage {
 public:
  Unnest(std::shared_ptr<Expr> field, absl::optional<std::string> index_field);
  ~Unnest() override = default;
  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::shared_ptr<Expr> field_;
  absl::optional<std::string> index_field_;
};

class RawStage : public Stage {
 public:
  RawStage(std::string name,
           std::vector<std::shared_ptr<Expr>> params,
           std::unordered_map<std::string, std::shared_ptr<Expr>> options);
  ~RawStage() override = default;
  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::string name_;
  std::vector<std::shared_ptr<Expr>> params_;
  std::unordered_map<std::string, std::shared_ptr<Expr>> options_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_STAGES_H_
