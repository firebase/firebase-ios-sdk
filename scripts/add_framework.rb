#!/usr/bin/env ruby

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

require 'xcodeproj'
require 'set'
require 'optparse'

options = {}
options[:source_tree] = "SOURCE_ROOT"
OptionParser.new do |opt|
  opt.on('--sdk SDK') { |o| options[:sdk] = o }
  opt.on('--target TARGET') { |o| options[:target] = o }
  opt.on('--framework_path FRAMEWORK_PATH') { |o| options[:framework_path] = o }
  opt.on('--source_tree SOURCE_TREE') { |o| options[:source_tree] = o }
end.parse!
sdk = options[:sdk]
target = options[:target]
framework_path = options[:framework_path]
source_tree = options[:source_tree]
project_path = "#{sdk}Example.xcodeproj"
project = Xcodeproj::Project.open(project_path)

if File.directory?(framework_path)
  framework_group = Dir.glob(File.join(framework_path, "*{framework,dylib}"))

  project.targets.each do |project_target|
    next unless project_target.name == target
    project_framework_group = project.frameworks_group
    framework_build_phase = project_target.frameworks_build_phase
    framework_set = project_target.frameworks_build_phase.files.to_set
    puts "The following frameworks are added to #{project_target}"
    framework_group.each do |framework|
      next if framework_set.size == framework_set.add(framework).size
      ref = project_framework_group.new_reference("#{framework}")
      ref.name = "#{File.basename(framework)}"
      ref.source_tree = source_tree
      framework_build_phase.add_file_reference(ref)
      puts ref
    end
  end
  project.save()
else 
  project.targets.each do |project_target|
    next unless project_target.name == target
    project_framework_group = project.frameworks_group
    framework_build_phase = project_target.frameworks_build_phase
    puts "The following file is added to #{project_target}"
    ref = project_framework_group.new_reference("#{framework_path}")
    ref.name = "#{File.basename(framework_path)}"
    ref.source_tree = source_tree
    framework_build_phase.add_file_reference(ref)
    puts ref
  end
  project.save()
end
