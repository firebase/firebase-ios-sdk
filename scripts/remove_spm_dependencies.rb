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

# This script removes all Swift Package Manager dependencies from an Xcode project.
# It's designed to be used in CI to prepare a project for framework-based testing.

# --- Argument Parsing ---
unless ARGV.length == 1
  puts "Usage: #{$0} <path_to.xcodeproj>"
  exit 1
end

project_path = ARGV[0]

# --- Main Logic ---
begin
  project = Xcodeproj::Project.open(project_path)
rescue => e
  puts "Error opening project at #{project_path}: #{e.message}"
  exit 1
end

puts "Opened project: #{project.path}"

# Remove package references from the project's root object.
# This corresponds to the "Package Dependencies" section in Xcode's navigator.
unless project.root_object.package_references.empty?
  puts "Removing #{project.root_object.package_references.count} package reference(s)..."
  project.root_object.package_references.clear
  puts "All package references removed from the project."
else
  puts "No package references found in the project."
end

# Remove package product dependencies from all targets.
# This removes the link to the package products in the "Frameworks, Libraries,
# and Embedded Content" section of each target.
project.targets.each do |target|
  dependencies_to_remove = target.dependencies.select do |dependency|
    dependency.is_a?(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  end

  unless dependencies_to_remove.empty?
    puts "Found #{dependencies_to_remove.count} SPM product dependencies in target '#{target.name}'. Removing..."
    dependencies_to_remove.each do |dep|
        puts "Removing #{dep.product_name}"
        target.dependencies.delete(dep)
    end
    puts "SPM product dependencies removed from target '#{target.name}'."
  else
    puts "No SPM product dependencies found in target '#{target.name}'."
  end
end

# Save the modified project.
begin
  project.save
  puts "Project saved successfully."
rescue => e
  puts "Error saving project: #{e.message}"
  exit 1
end
