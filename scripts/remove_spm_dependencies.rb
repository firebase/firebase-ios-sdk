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

# This script removes Swift Package Manager dependencies from an Xcode project.
# It can remove all dependencies or a specified list of dependencies.
# It's designed to be used in CI to prepare a project for framework-based testing.

# --- Argument Parsing ---
unless ARGV.length >= 1
  puts "Usage: #{$0} <path_to.xcodeproj> [dependency_name_1 dependency_name_2 ...]"
  puts "If no dependency names are provided, all SPM dependencies will be removed."
  exit 1
end

project_path = ARGV[0]
# If more than one argument is provided, treat the rest as a list of dependencies to remove.
# Otherwise, deps_to_remove_names will be nil, signaling that all dependencies should be removed.
deps_to_remove_names = ARGV.length > 1 ? ARGV[1..-1].to_set : nil


# --- Main Logic ---
begin
  project = Xcodeproj::Project.open(project_path)
rescue => e
  puts "Error opening project at #{project_path}: #{e.message}"
  exit 1
end

puts "Opened project: #{project.path}"

# --- Step 1: Find all SPM product dependencies ---
all_package_product_dependencies = project.objects.select do |obj|
  obj.is_a?(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
end

if all_package_product_dependencies.empty?
  puts "No SPM product dependencies found in the project."
  # Still, try to clean up package references if they exist.
  unless project.root_object.package_references.empty?
    puts "Removing #{project.root_object.package_references.count} orphaned package reference(s)..."
    project.root_object.package_references.clear
    project.save
    puts "Project saved."
  end
  exit 0
end

# --- Step 2: Determine which dependencies to remove and which to keep ---
dependencies_to_remove = []
dependencies_to_keep = []

if deps_to_remove_names
  puts "Attempting to remove specific dependencies: #{deps_to_remove_names.to_a.join(', ')}"
  all_package_product_dependencies.each do |dep|
    if deps_to_remove_names.include?(dep.product_name)
      dependencies_to_remove << dep
    else
      dependencies_to_keep << dep
    end
  end

  found_dep_names = dependencies_to_remove.map(&:product_name).to_set
  not_found = deps_to_remove_names - found_dep_names
  unless not_found.empty?
    puts "Warning: The following specified dependencies were not found: #{not_found.to_a.join(', ')}"
  end
else
  puts "No specific dependencies provided. Removing all #{all_package_product_dependencies.count} SPM dependencies."
  dependencies_to_remove = all_package_product_dependencies
  # dependencies_to_keep remains empty
end

if dependencies_to_remove.empty?
  puts "No SPM product dependencies to remove."
  exit 0
end

# --- Step 3: Remove dependencies and their references ---
puts "Found #{dependencies_to_remove.count} SPM product dependencies to remove. Removing all references..."
package_product_dep_uuids = dependencies_to_remove.map(&:uuid).to_set

# Find all BuildFile objects that reference these SPM products
build_files_to_remove = project.objects.select do |obj|
  obj.is_a?(Xcodeproj::Project::Object::PBXBuildFile) &&
  obj.product_ref &&
  package_product_dep_uuids.include?(obj.product_ref.uuid)
end
build_file_uuids_to_remove = build_files_to_remove.map(&:uuid).to_set

# Remove references from all targets
project.targets.each do |target|
  puts "Cleaning target '#{target.name}'..."

  # Remove from target dependencies list
  removed_deps = target.dependencies.reject! do |dep|
    package_product_dep_uuids.include?(dep.uuid)
  end
  if removed_deps
    puts "  - Removed #{removed_deps.count} SPM target dependencies."
  end

  # Remove from build phases (e.g., "Link Binary With Libraries")
  target.build_phases.each do |phase|
    next unless phase.respond_to?(:files)

    original_file_count = phase.files.count
    phase.files.reject! do |build_file|
      build_file_uuids_to_remove.include?(build_file.uuid)
    end
    removed_count = original_file_count - phase.files.count
    if removed_count > 0
      puts "  - Removed #{removed_count} SPM build file references from '#{phase.display_name}'."
    end
  end
end

# Delete the now-orphaned BuildFile and dependency objects
puts "Deleting #{build_files_to_remove.count} SPM BuildFile object(s)..."
build_files_to_remove.each(&:remove_from_project)

puts "Deleting #{dependencies_to_remove.count} SPM product dependency object(s)..."
dependencies_to_remove.each(&:remove_from_project)


# --- Step 4: Remove package references from the project root ---
if deps_to_remove_names
  # If we are removing a subset of dependencies, only remove package references
  # if no other products from that package are being used.
  packages_to_keep = dependencies_to_keep.map(&:package).compact.to_set

  original_count = project.root_object.package_references.count
  project.root_object.package_references.reject! do |ref|
    !packages_to_keep.include?(ref)
  end
  removed_count = original_count - project.root_object.package_references.count
  if removed_count > 0
    puts "Removed #{removed_count} package reference(s) that no longer have products in use."
  else
    puts "No package references needed to be removed."
  end
else
  # Remove all package references if we are removing all dependencies.
  unless project.root_object.package_references.empty?
    puts "Removing #{project.root_object.package_references.count} package reference(s)..."
    project.root_object.package_references.clear
    puts "All package references removed from the project."
  else
    puts "No package references found in the project."
  end
end


# --- Step 5: Save the modified project ---
begin
  project.save
  puts "Project saved successfully."
rescue => e
  puts "Error saving project: #{e.message}"
  exit 1
end
