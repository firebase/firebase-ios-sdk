#!/usr/bin/env ruby

# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may
# obtain a copy of the License at
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

# --- Step 1: Find all SPM product dependencies ---
package_product_dependencies = project.objects.select do |obj|
  obj.is_a?(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
end

if package_product_dependencies.empty?
  puts "No SPM product dependencies found to remove."
else
  puts "Found #{package_product_dependencies.count} SPM product dependencies. Removing all references..."
  package_product_dep_uuids = package_product_dependencies.map(&:uuid).to_set

  # --- Step 2: Find all BuildFile objects that reference these SPM products ---
  build_files_to_remove = project.objects.select do |obj|
    obj.is_a?(Xcodeproj::Project::Object::PBXBuildFile) &&
    obj.product_ref &&
    package_product_dep_uuids.include?(obj.product_ref.uuid)
  end
  build_file_uuids_to_remove = build_files_to_remove.map(&:uuid).to_set

  # --- Step 3: Remove references from all targets ---
  project.targets.each do |target|
    puts "Cleaning target '#{target.name}'..."

    # Remove from target dependencies list
    dependencies_to_remove = target.dependencies.select do |dep|
      package_product_dep_uuids.include?(dep.uuid)
    end

    unless dependencies_to_remove.empty?
      puts "  - Removed #{dependencies_to_remove.count} SPM target dependencies:"
      dependencies_to_remove.each do |dep|
        product_name = dep.respond_to?(:product_name) ? dep.product_name : dep.display_name
        puts "    - #{product_name}"
      end
      target.dependencies.reject! { |dep| package_product_dep_uuids.include?(dep.uuid) }
    end

    # Remove from build phases (e.g., "Link Binary With Libraries")
    target.build_phases.each do |phase|
      next unless phase.respond_to?(:files)

      build_files_to_remove_from_phase = phase.files.select do |build_file|
        build_file_uuids_to_remove.include?(build_file.uuid)
      end

      unless build_files_to_remove_from_phase.empty?
        puts "  - Removed #{build_files_to_remove_from_phase.count} SPM build file references from '#{phase.display_name}':"
        build_files_to_remove_from_phase.each do |bf|
          product_name = bf.product_ref ? bf.product_ref.product_name : bf.display_name
          puts "    - #{product_name}"
        end
        phase.files.reject! { |build_file| build_file_uuids_to_remove.include?(build_file.uuid) }
      end
    end
  end

  # --- Step 4: Delete the now-orphaned BuildFile and dependency objects ---
  puts "Deleting #{build_files_to_remove.count} SPM BuildFile object(s)..."
  build_files_to_remove.each do |build_file|
    product_name = build_file.product_ref ? build_file.product_ref.product_name : build_file.display_name
    puts "  - BuildFile for #{product_name}"
    build_file.remove_from_project
  end

  puts "Deleting #{package_product_dependencies.count} SPM product dependency object(s)..."
  package_product_dependencies.each do |dependency|
    puts "  - #{dependency.product_name}"
    dependency.remove_from_project
  end
end

# --- Step 5: Remove package references from the project root ---
unless project.root_object.package_references.empty?
  puts "Removing #{project.root_object.package_references.count} package reference(s):"
  project.root_object.package_references.each do |ref|
    name = ref.name || (ref.respond_to?(:repository_url) ? ref.repository_url : ref.path)
    puts "  - #{name}"
  end
  project.root_object.package_references.clear
  puts "All package references removed from the project."
else
  puts "No package references found in the project."
end

# --- Step 6: Save the modified project ---
begin
  project.save
  puts "Project saved successfully."
rescue => e
  puts "Error saving project: #{e.message}"
  exit 1
end
