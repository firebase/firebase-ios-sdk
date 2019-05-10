#!/usr/bin/env bash

# Copyright 2019 Google
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# USAGE: ./collect_metrics.sh workspace scheme
#
# Collects project health metrics and uploads them to a database. Currently just collects code
# coverage for the provided workspace and scheme. Assumes that those tests have already been
# executed.

set -euo pipefail

if [[ $# -ne 2 ]]; then
  cat 1>&2 <<EOF
USAGE: $0 workspace scheme

Collects project health metrics and uploads them to a database. Currently just collects code
coverage for the provided workspace and scheme. Assumes that those tests have already been
executed.
EOF
  exit 1
fi

if [[ "${TRAVIS_PULL_REQUEST}" != "false" ]]; then
  WORKSPACE="$1"
  SCHEME="$2"

  gem install xcov
  xcov --workspace "${WORKSPACE}" --scheme "${SCHEME}" --output_directory Metrics --json_report
  cd Metrics
  swift build
  .build/debug/Metrics -c report.json -p "${TRAVIS_PULL_REQUEST}"
  cd ..
fi
