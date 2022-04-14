# frozen_string_literal: true

# Copyright 2020 Google LLC
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

require 'octokit'
require 'optparse'
require 'json'

REPO_NAME_WITH_OWNER = ENV['GITHUB_REPOSITORY']
GITHUB_WORKFLOW_URL = "https://github.com/#{REPO_NAME_WITH_OWNER}/actions/runs/#{ENV['GITHUB_RUN_ID']}"
TESTS_TIME_INTERVAL_IN_HOURS = 24
TESTS_TIME_INTERVAL_IN_SECS = TESTS_TIME_INTERVAL_IN_HOURS * 3600
NO_WORKFLOW_RUNNING_INFO = "All nightly cron job were not run in the last #{TESTS_TIME_INTERVAL_IN_HOURS} hrs. Please review [log](#{GITHUB_WORKFLOW_URL}) make sure there at least exists one cron job running.".freeze
EXCLUDED_WORKFLOWS = []
ISSUE_LABELS = ""
ISSUE_TITLE = "Auto-Generated Testing Report"

puts "Hello World."
