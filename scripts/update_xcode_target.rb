#!/usr/bin/env ruby

# Copyright 2021 Google LLC
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

# Script to add a file to an Xcode target.
# Adapted from https://github.com/firebase/quickstart-ios/blob/master/scripts/info_script.rb

require 'xcodeproj'
project_path = ARGV[0]
target = ARGV[1]
file_name = ARGV[2]

project = Xcodeproj::Project.open(project_path)

# Add a file to the project in the main group
file = project.new_file(file_name)

# Add the file to the all targets
project.targets.each do |t|
  if t.to_s == target
    if file_name.end_with?(".json") then
      t.add_resources([file])
    else
      t.add_file_references([file])
    end
  end
end

# Save project
project.save()
