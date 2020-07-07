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
options[:file_ext] = "xcframework,framework,dylib"
OptionParser.new do |opt|
  opt.on('--sdk SDK') { |o| options[:sdk] = o }
  opt.on('--target TARGET') { |o| options[:target] = o }
  opt.on('--framework_path FRAMEWORK_PATH') { |o| options[:framework_path] = o }
  opt.on('--source_tree SOURCE_TREE') { |o| options[:source_tree] = o }
  opt.on('--file_ext FILE_EXT') { |o| options[:file_ext] = o}
end.parse!
sdk = options[:sdk]
target = options[:target]
framework_path = options[:framework_path]
source_tree = options[:source_tree]
file_ext = options[:file_ext]
project_path = "#{sdk}Example.xcodeproj"
project = Xcodeproj::Project.open(project_path)
project_framework_group = project.frameworks_group

def add_ref(group, path, source_tree, phase)
  ref = group.new_reference("#{path}")
  ref.name = "#{File.basename(path)}"
  ref.source_tree = source_tree
  phase.add_file_reference(ref)
  puts ref
end

if File.directory?(framework_path)
  if framework_path.end_with?("bundle")
    project.targets.each do |project_target|
      next unless project_target.name == target
      puts "The following bundle is added to #{project_target}"
      add_ref(project.main_group,
              framework_path,
              source_tree,
              project_target.resources_build_phase)
    end
  else
    framework_group = Dir.glob(File.join(framework_path, "*.{#{file_ext}}"))

    project.targets.each do |project_target|
      next unless project_target.name == target
      framework_set = project_target.frameworks_build_phase.files.to_set
      puts "The following frameworks are added to #{project_target}"
      framework_group.each do |framework|
        next if framework_set.size == framework_set.add(framework).size
        add_ref(project_framework_group,
                framework,
                source_tree,
                project_target.frameworks_build_phase)
      end
    end
  end
else
  project.targets.each do |project_target|
    next unless project_target.name == target
    puts "The following file is added to #{project_target}"
    add_ref(project_framework_group,
            framework_path,
            source_tree,
            project_target.frameworks_build_phase)
  end
end
project.save()
