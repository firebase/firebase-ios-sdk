#!/usr/bin/env ruby

# Copyright 2025 Google LLC
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

require 'xcodeproj'

# This script patches the Crashlytics Quickstart's Xcode project to fix the
# path to the `run` script for XCFramework-based builds.
#
# The default project assumes an SPM dependency. This script changes the path
# to point to the location where the `run` script is placed in the zip
# distribution test environment.

project_path = 'quickstart-ios/crashlytics/CrashlyticsExample.xcodeproj'
project = Xcodeproj::Project.open(project_path)
new_path = '"${SRCROOT}/Firebase/run"'

project.targets.each do |target|
  target.build_phases.each do |phase|
    if phase.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase) && phase.name == 'Run Script'
      if phase.shell_script.include?('SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run')
        puts "Patching Run Script phase in target '#{target.name}' to: #{new_path}"
        phase.shell_script = new_path
      end
    end
  end
end

project.save
