# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  indexes = {
    index1 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "a"
        order      = "ASCENDING"
      },
    ]
    index2 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "b"
        order      = "ASCENDING"
      },
    ]
    index3 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "b"
        order      = "DESCENDING"
      },
    ]
    index4 = [
      {
        field_path = "a"
        order      = "ASCENDING"
      },
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "b"
        order      = "ASCENDING"
      },
    ]
    index5 = [
      {
        field_path = "a"
        order      = "ASCENDING"
      },
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "b"
        order      = "DESCENDING"
      },
    ]
    index6 = [
      {
        field_path = "a"
        order      = "ASCENDING"
      },
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "a"
        order      = "DESCENDING"
      },
    ]
    index7 = [
      {
        field_path = "b"
        order      = "ASCENDING"
      },
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "a"
        order      = "ASCENDING"
      },
    ]
    index8 = [
      {
        field_path = "b"
        order      = "ASCENDING"
      },
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "a"
        order      = "DESCENDING"
      },
    ]
    index9 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "a"
        order      = "ASCENDING"
      },

      {
        field_path = "b"
        order      = "ASCENDING"
      },
    ]
    index10 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "b"
        order      = "DESCENDING"
      },

      {
        field_path = "a"
        order      = "DESCENDING"
      },
    ]
    index11 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "pages"
        order      = "ASCENDING"
      },
      {
        field_path = "year"
        order      = "ASCENDING"
      },
    ]
    index12 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "pages"
        order      = "ASCENDING"
      },
      {
        field_path = "rating"
        order      = "ASCENDING"
      },
      {
        field_path = "year"
        order      = "ASCENDING"
      },
    ]
    index13 = [
      {
        field_path   = "rating"
        array_config = "CONTAINS"
      },
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "pages"
        order      = "ASCENDING"
      },
      {
        field_path = "rating"
        order      = "ASCENDING"
      },
    ]
    index14 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "key"
        order      = "ASCENDING"
      },
      {
        field_path = "sort"
        order      = "ASCENDING"
      }
    ]
    index15 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "key"
        order      = "ASCENDING"
      },
      {
        field_path = "sort"
        order      = "ASCENDING"
      },
      {
        field_path = "v"
        order      = "ASCENDING"
      }
    ]
    index16 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "v"
        order      = "DESCENDING"
      },
      {
        field_path = "key"
        order      = "DESCENDING"
      },
      {
        field_path = "sort"
        order      = "DESCENDING"
      },
    ]
    index17 = [
      {
        field_path   = "v"
        array_config = "CONTAINS"
      },
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "key"
        order      = "ASCENDING"
      },
      {
        field_path = "sort"
        order      = "ASCENDING"
      },
    ]
    index18 = [
      {
        field_path = "key"
        order      = "ASCENDING"
      },
      {
        field_path = "testId"
        order      = "ASCENDING"
      },

      {
        field_path = "sort"
        order      = "DESCENDING"
      },
      {
        field_path = "v"
        order      = "ASCENDING"
      },
    ]
    index19 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },

      {
        field_path = "sort"
        order      = "DESCENDING"
      },
      {
        field_path = "key"
        order      = "ASCENDING"
      },
      {
        field_path = "v"
        order      = "ASCENDING"
      },
    ]
    index20 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "v"
        order      = "ASCENDING"
      },

      {
        field_path = "sort"
        order      = "ASCENDING"
      },
      {
        field_path = "key"
        order      = "ASCENDING"
      },

    ]
    index21 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "sort"
        order      = "DESCENDING"
      },
      {
        field_path = "key"
        order      = "DESCENDING"
      },

    ]
    index22 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "v"
        order      = "DESCENDING"
      },
      {
        field_path = "sort"
        order      = "ASCENDING"
      },
      {
        field_path = "key"
        order      = "ASCENDING"
      },
    ]
    index23 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "name"
        order      = "ASCENDING"
      },
      {
        field_path = "metadata.createdAt"
        order      = "ASCENDING"
      },
    ]
    index24 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "name"
        order      = "DESCENDING"
      },
      {
        field_path = "field"
        order      = "DESCENDING"
      },
      {
        field_path = "`field.dot`"
        order      = "DESCENDING"
      },
      {
        field_path = "`field\\\\slash`"
        order      = "DESCENDING"
      },
    ],
    index25 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "v"
        order      = "ASCENDING"
      },
      {
        field_path = "key"
        order      = "ASCENDING"
      },
      {
        field_path = "sort"
        order      = "ASCENDING"
      },
    ]
  }
}