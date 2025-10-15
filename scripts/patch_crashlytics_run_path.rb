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
# The default project assumes an SPM dependency and has a hardcoded path:
#  ${BUILD_DIR%Build/*}SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run
#
# This script changes it to the path used by the XCFramework distribution:
#  "${SRCROOT}/Firebase/FirebaseCrashlytics/run"

project_path = 'quickstart-ios/crashlytics/CrashlyticsExample.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  target.build_phases.each do |phase|
    if phase.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase) && phase.name == 'Run Script'
      if phase.shell_script.include?('SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run')
        puts "Patching Run Script phase in target: #{target.name}"
        phase.shell_script = '"${SRCROOT}/Firebase/FirebaseCrashlytics/run"'
      end
    end
  end
end

project.save
