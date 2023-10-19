#!/usr/bin/env ruby

# Copyright 2018 Google
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

# Syncs Xcode project folder and target structure with the filesystem. This
# script finds all files on the filesystem that match the patterns supplied
# below and changes the project to match what it found.
#
# Run this script after adding/removing tests to keep the project in sync.

require 'cocoapods'
require 'optparse'
require 'pathname'

# Note that xcodeproj 1.5.8 appears to be broken
# https://github.com/CocoaPods/Xcodeproj/issues/572
gem 'xcodeproj', '!= 1.5.8'
require 'xcodeproj'


ROOT_DIR = Pathname.new(__FILE__).dirname().join('..').expand_path()
PODFILE_DIR = ROOT_DIR.join('Firestore', 'Example')


def main()
  test_only = false
  OptionParser.new do |opts|
    opts.on('--test-only', 'Check diffs without writing') do |v|
      test_only = v
    end
  end.parse!

  # Make all filenames relative to the project root.
  Dir.chdir(ROOT_DIR.to_s)

  changes = sync_firestore(test_only)
  status = test_only && changes > 0 ? 2 : 0
  exit(status)
end


# Make it so that you can "add" hash literals together by merging their
# contents.
class Hash
  def +(other)
    return merge(other)
  end
end


def sync_firestore(test_only)
  project = Xcodeproj::Project.open('Firestore/Example/Firestore.xcodeproj')
  spec = Pod::Spec.from_file('FirebaseFirestoreInternal.podspec')
  swift_spec = Pod::Spec.from_file('FirebaseFirestore.podspec')

  # Enable warnings after opening the project to avoid the warnings in
  # xcodeproj itself
  $VERBOSE = true

  s = Syncer.new(project, ROOT_DIR)

  # Files on the filesystem that should be ignored.
  s.ignore_files = [
    'CMakeLists.txt',
    'README.md',
    'InfoPlist.strings',
    '*.orig',
    '*.plist',
    '.*',
  ]

  # Folder groups in the Xcode project that contain tests.
  s.groups = [
    'Tests',
    'CoreTests',
    'CoreTestsProtos',
    'SwiftTests',
  ]

  # Copy key settings from the podspec
  podspec_settings = [
    'CLANG_CXX_LANGUAGE_STANDARD',
    'GCC_C_LANGUAGE_STANDARD',
  ]
  xcconfig_spec = spec.attributes_hash['pod_target_xcconfig'].dup
  xcconfig_spec.select! { |k, v| podspec_settings.include?(k) }

  # Settings for all Objective-C/C++ targets
  xcconfig_objc = xcconfig_spec + {
    'INFOPLIST_FILE' => '"${SRCROOT}/Tests/Tests-Info.plist"',

    # Duplicate the header search paths from the main podspec because they're
    # phrased in terms of PODS_TARGET_SRCROOT, which isn't defined for other
    # targets.
    'HEADER_SEARCH_PATHS' => [
      # Include fully qualified from the root of the repo
      '"${PODS_ROOT}/../../.."',

      # Make public headers available as "FIRQuery.h"
      '"${PODS_ROOT}/../../../Firestore/Source/Public/FirebaseFirestore"',

      # Generated protobuf and nanopb output expects to search relative to the
      # output path.
      '"${PODS_ROOT}/../../../Firestore/Protos/cpp"',
      '"${PODS_ROOT}/../../../Firestore/Protos/nanopb"',

      # Other dependencies that assume #includes are relative to their roots.
      '"${PODS_ROOT}/../../../Firestore/third_party/abseil-cpp"',
      '"${PODS_ROOT}/GoogleBenchmark/include"',
      '"${PODS_ROOT}/GoogleTest/googlemock/include"',
      '"${PODS_ROOT}/GoogleTest/googletest/include"',
      '"${PODS_ROOT}/leveldb-library/include"',
    ],

    'SYSTEM_HEADER_SEARCH_PATHS' => [
      # Nanopb wants to #include <pb.h>
      '"${PODS_ROOT}/nanopb"',

      # Protobuf wants to #include <google/protobuf/stubs/common.h>
      '"${PODS_ROOT}/ProtobufCpp/src"',
    ],

    'OTHER_CFLAGS' => [
      # Protobuf C++ generates dead code.
      '-Wno-unreachable-code',

      # Our public build can't include -Werror, but for development it's quite
      # helpful.
      '-Werror'
    ]
  }

  xcconfig_swift = {
    'SWIFT_OBJC_BRIDGING_HEADER' =>
        '${PODS_ROOT}/../../../Firestore/Swift/Tests/BridgingHeader.h',
    'SWIFT_VERSION' => pick_swift_version(swift_spec),
  }

  ['iOS', 'macOS', 'tvOS'].each do |platform|
    s.target "Firestore_Example_#{platform}" do |t|
      t.xcconfig = xcconfig_objc + xcconfig_swift + {
        # Passing -all_load is required to get all our C++ code into the test
        # host.
        #
        # Normally when running tests, the test target contains only the tests
        # proper, and links against the test host for the code under test. The
        # test host doesn't do anything though, so the linker strips C++-only
        # object code away.
        #
        # This is particular to C++ because by default CocoaPods configures the
        # test host to link with the -ObjC flag. This causes the linker to pull
        # in all Objective-C object code. -all_load fixes this by forcing the
        # linker to pull in everything.
        'OTHER_LDFLAGS' => '-all_load',
      }
    end

    s.target "Firestore_Tests_#{platform}" do |t|
      t.source_files = [
        'Firestore/Example/Tests/**',
        'Firestore/core/test/**',
        'Firestore/Protos/cpp/**',
      ]
      t.exclude_files = [
        # needs to be in project but not in target
        'Firestore/Example/Tests/Tests-Info.plist',

        # These files are integration tests, handled below
        'Firestore/Example/Tests/Integration/**',
      ]
      t.xcconfig = xcconfig_objc + xcconfig_swift
    end
  end

  ['iOS', 'macOS', 'tvOS'].each do |platform|
    s.target "Firestore_IntegrationTests_#{platform}" do |t|
      t.source_files = [
        'Firestore/Example/Tests/**',
        'Firestore/Protos/cpp/**',
        'Firestore/Swift/Tests/**',
        'Firestore/core/test/**',
      ]
      t.exclude_files = [
        # needs to be in project but not in target
        'Firestore/Example/Tests/Tests-Info.plist',
      ]
      t.xcconfig = xcconfig_objc + xcconfig_swift
    end

    s.target 'Firestore_Benchmarks_iOS' do |t|
      t.xcconfig = xcconfig_objc + {
        'INFOPLIST_FILE' => '${SRCROOT}/Benchmarks/Info.plist',
      }
    end

    s.target 'Firestore_FuzzTests_iOS' do |t|
      t.xcconfig = xcconfig_objc + {
        'INFOPLIST_FILE' =>
            '${SRCROOT}/FuzzTests/Firestore_FuzzTests_iOS-Info.plist',
        'OTHER_CFLAGS' => [
            '-fsanitize=fuzzer',
        ]
      }

    end
  end

  changes = s.sync(test_only)
  if not test_only
    sort_project(project)
    if project.dirty?
      project.save()
    end
  end
  return changes
end


# Picks a swift version to use from a podspec's swift_versions
def pick_swift_version(spec)
  versions = spec.attributes_hash['swift_versions']
  if versions.is_a?(Array)
    return versions[-1]
  end
  return versions
end


# A list of filesystem patterns
class PatternList
  def initialize()
    @patterns = []
  end

  attr_accessor :patterns

  # Evaluates the rel_path against the given list of fnmatch patterns.
  def matches?(rel_path)
    @patterns.each do |pattern|
      if rel_path.fnmatch?(pattern)
        return true
      end
    end
    return false
  end
end


# The definition of a test target including the target name, its source_files
# and exclude_files. A file is considered part of a target if it matches a
# pattern in source_files but does not match a pattern in exclude_files.
class TargetDef
  def initialize(name)
    @name = name
    @sync_sources = false
    @source_files = PatternList.new()
    @exclude_files = PatternList.new()

    @xcconfig = {}
  end

  attr_reader :name, :sync_sources, :source_files, :exclude_files
  attr_accessor :xcconfig

  def source_files=(value)
    @sync_sources = true
    @source_files.patterns.replace(value)
  end

  def exclude_files=(value)
    @exclude_files.patterns.replace(value)
  end

  # Returns true if the given rel_path matches this target's source_files
  # but not its exclude_files.
  #
  # Args:
  # - rel_path: a Pathname instance with a path relative to the project root.
  def matches?(rel_path)
    return @source_files.matches?(rel_path) && !@exclude_files.matches?(rel_path)
  end

  def diff(project_files, target)
    diff = Diff.new

    project_files.each do |file_ref|
      if matches?(relative_path(file_ref))
        entry = diff.track(file_ref.real_path)
        entry.in_source = true
        entry.ref = file_ref
      end
    end

    each_target_file(target) do |file_ref|
      entry = diff.track(file_ref.real_path)
      entry.in_target = true
      entry.ref = file_ref
    end

    return diff
  end

  # We're only managing synchronization of files in these phases.
  INTERESTING_PHASES = [
    Xcodeproj::Project::Object::PBXHeadersBuildPhase,
    Xcodeproj::Project::Object::PBXSourcesBuildPhase,
    Xcodeproj::Project::Object::PBXResourcesBuildPhase,
  ]

  # Finds all the files referred to by any phase in a target
  def each_target_file(target)
    target.build_phases.each do |phase|
      next if not INTERESTING_PHASES.include?(phase.class)

      phase.files.each do |build_file|
        yield build_file.file_ref
      end
    end
  end
end


class Syncer
  HEADERS = %w{.h}
  SOURCES = %w{.c .cc .m .mm .swift}

  def initialize(project, root_dir)
    @project = project
    @finder = DirectoryLister.new(root_dir)

    @groups = []
    @targets = []

    @seen_groups = {}
  end

  # Considers the given fnmatch glob patterns to be ignored by the syncer.
  # Patterns are matched both against the basename and project-relative
  # qualified pathname.
  def ignore_files=(patterns)
    @finder.add_patterns(patterns)
  end

  # Names the groups within the project that serve as roots for tests within
  # the project.
  def groups=(groups)
    @groups = []
    groups.each do |group|
      project_group = @project[group]
      if project_group.nil?
        raise "Project does not contain group #{group}"
      end
      @groups.push(@project[group])
    end
  end

  # Starts a new target block. Creates a new TargetDef and yields it.
  def target(name, &block)
    t = TargetDef.new(name)
    @targets.push(t)

    block.call(t)
  end

  # Finds the target definition with the given name.
  def find_target(name)
    @targets.each do |target|
      if target.name == name
        return target
      end
    end
    return nil
  end

  # Synchronizes the filesystem with the project.
  #
  # Generally there are three separate ways a file is referenced within a project:
  #
  #  1. The file must be in the global list of files, assigning it a UUID.
  #  2. The file must be added to folder groups, describing where it is in the
  #     folder view of the Project Navigator.
  #  3. The file must be added to a target phase describing how it's built.
  #
  # The Xcodeproj library handles (1) for us automatically if we do (2).
  #
  # Returns the number of changes made during synchronization.
  def sync(test_only = false)
    # Figure the diff between the filesystem and the group structure
    group_differ = GroupDiffer.new(@finder)
    group_diff = group_differ.diff(@groups)
    changes = group_diff.changes
    to_remove = group_diff.to_remove

    # Add all files first, to ensure they exist for later steps
    add_to_project(group_diff.to_add)

    project_files = find_project_files_after_removal(@project.files, to_remove)

    @project.native_targets.each do |target|
      target_def = find_target(target.name)
      next if target_def.nil?

      if target_def.sync_sources
        target_diff = target_def.diff(project_files, target)
        target_diff.sorted_entries.each do |entry|
          changes += sync_target_entry(target, entry)
        end
      end

      if not test_only
        # Don't sync xcconfig changes in test-only mode.
        sync_xcconfig(target_def, target)
      end
    end

    remove_from_project(to_remove)
    return changes
  end

  private

  def find_project_files_after_removal(files, to_remove)
    remove_paths = Set.new()
    to_remove.each do |entry|
      remove_paths.add(entry.path)
    end

    result = []
    files.each do |file_ref|
      next if file_ref.source_tree != '<group>'

      next if remove_paths.include?(file_ref.real_path)

      path = file_ref.real_path
      next if @finder.ignore_basename?(path.basename)
      next if @finder.ignore_pathname?(path)

      result.push(file_ref)
    end
    return result
  end

  # Adds the given file to the project, in a path starting from the test root
  # that fully prefixes the file.
  def add_to_project(to_add)
    to_add.each do |entry|
      path = entry.path
      root_group = find_group_containing(path)

      # Find or create the group to contain the path.
      dir_rel_path = path.relative_path_from(root_group.real_path).dirname
      group = root_group.find_subpath(dir_rel_path.to_s, true)

      file_ref = group.new_file(path.to_s)
      ext = path.extname

      entry.ref = file_ref
    end
  end

  # Finds a group whose path prefixes the given entry. Starting from the
  # project root may not work since not all directories exist within the
  # example app.
  def find_group_containing(path)
    @groups.each do |group|
      rel = path.relative_path_from(group.real_path)
      next if rel.to_s.start_with?('..')

      return group
    end

    raise "Could not find an existing group that's a parent of #{entry.path}"
  end

  # Removes the given file references from the project after the file is found
  # to not exist on the filesystem but references to it still exist in the
  # project.
  def remove_from_project(to_remove)
    to_remove.each do |entry|
      file_ref = entry.ref
      file_ref.remove_from_project
    end
  end

  # Syncs a single build file for a given phase. Returns the number of changes
  # made.
  def sync_target_entry(target, entry)
    return 0 if entry.unchanged?

    phase = find_phase(target, entry.path)
    return 0 if phase.nil?

    mark_change_in_group(target.display_name)
    if entry.to_add?
      printf("  %s - added\n", basename(entry.ref))
      phase.add_file_reference(entry.ref)
    else
      printf("  %s - removed\n", basename(entry.ref))
      phase.remove_file_reference(entry.ref)
    end

    return 1
  end

  # Finds the phase to which the given pathname belongs based on its file
  # extension.
  #
  # Returns nil if the path does not belong in any phase.
  def find_phase(target, path)
    path = normalize_to_pathname(path)
    ext = path.extname
    if SOURCES.include?(ext)
      return target.source_build_phase
    elsif HEADERS.include?(ext)
      # TODO(wilhuff): sync headers
      #return target.headers_build_phase
      return nil
    else
      return target.resources_build_phase
    end
  end

  # Syncs build settings to the .xcconfig file for the build configuration,
  # avoiding any changes to the Xcode project file.
  def sync_xcconfig(target_def, target)
    dirty = false
    target.build_configurations.each do |config|
      requested = flatten(target_def.xcconfig)

      if config.base_configuration_reference.nil?
        # Running pod install with PLATFORM set to something other than "all"
        # ends up removing baseConfigurationReference entries from the project
        # file. Skip these entries when re-running.
        puts "Skipping #{target.name} (#{config.name})"
        next
      end

      path = PODFILE_DIR.join(config.base_configuration_reference.real_path)
      if !File.file?(path)
        puts "Skipping #{target.name} (#{config.name}); missing xcconfig"
        next
      end

      contents = Xcodeproj::Config.new(path)
      contents.merge!(requested)
      contents.save_as(path)
    end
  end

  # Converts a hash of lists to a flat hash of strings.
  def flatten(xcconfig)
    result = {}
    xcconfig.each do |key, value|
      if value.is_a?(Array)
        value = value.join(' ')
      end
      result[key] = value
    end
    return result
  end
end


def normalize_to_pathname(file_ref)
  if !file_ref.is_a? Pathname
    if file_ref.is_a? String
      file_ref = Pathname.new(file_ref)
    else
      file_ref = file_ref.real_path
    end
  end
  return file_ref
end


def basename(file_ref)
  return normalize_to_pathname(file_ref).basename
end


def relative_path(file_ref)
  path = normalize_to_pathname(file_ref)
  return path.relative_path_from(ROOT_DIR)
end


def mark_change_in_group(group)
  path = group.to_s
  if !@seen_groups.has_key?(path)
    puts "#{path} ..."
    @seen_groups[path] = true
  end
end


def sort_project(project)
  project.groups.each do |group|
    sort_group(group)
  end

  project.targets.each do |target|
    target.build_phases.each do |phase|
      phase.files.sort! { |a, b|
        a.file_ref.real_path.basename <=> b.file_ref.real_path.basename
      }
    end
  end
end


def sort_group(group)
  group.groups.each do |child|
    sort_group(child)
  end

  group.children.sort! do |a, b|
    # Sort groups first
    if a.isa == 'PBXGroup' && b.isa != 'PBXGroup'
      -1
    elsif a.isa != 'PBXGroup' && b.isa == 'PBXGroup'
      1
    elsif a.display_name && b.display_name
      File.basename(a.display_name) <=> File.basename(b.display_name)
    else
      0
    end
  end
end


# Tracks how a file is referenced: in the project file, on the filesystem,
# neither, or both.
class DiffEntry
  def initialize(path)
    @path = path
    @in_source = false
    @in_target = false
    @ref = nil
  end

  attr_reader :path
  attr_accessor :in_source, :in_target, :ref

  def unchanged?()
    return @in_source && @in_target
  end

  def to_add?()
    return @in_source && !@in_target
  end

  def to_remove?()
    return !@in_source && @in_target
  end
end


# A set of differences between some source and a target.
class Diff
  def initialize()
    @entries = {}
  end

  attr_accessor :entries

  def track(path)
    if @entries.has_key?(path)
      return @entries[path]
    end

    entry = DiffEntry.new(path)
    @entries[path] = entry
    return entry
  end

  # Returns a list of entries that are to be added to the target
  def to_add()
    return @entries.values.select { |entry| entry.to_add? }
  end

  # Returns a list of entries that are to be removed to the target
  def to_remove()
    return @entries.values.select { |entry| entry.to_remove? }
  end

  # Returns a list of entries in sorted order.
  def sorted_entries()
    return @entries.values.sort { |a, b| a.path.basename <=> b.path.basename }
  end

  def changes()
    return @entries.values.count { |entry| entry.to_add? || entry.to_remove? }
  end
end


# Diffs folder groups against the filesystem directories referenced by those
# folder groups.
#
# Folder groups in the project may each refer to an arbitrary path, so
# traversing from a parent group to a subgroup may jump to a radically
# different filesystem location or alias a previously processed directory.
#
# This class performs a diff by essentially tracking only whether or not a
# given absolute path has been seen in either the filesystem or the group
# structure, without paying attention to where in the group structure the file
# reference actually occurs.
#
# This helps ensure that the default arbitrary splits in group structure are
# preserved. For example, "Supporting Files" is an alias for the same directory
# as the parent group, and Apple's default project setup hides some files in
# "Supporting Files". The approach this diff takes preserves this arrangement
# without understanding specifically which files should be hidden and which
# should exist in the parent.
#
# However, this approach has limitations: removing a file from "Supporting
# Files" will be handled, but re-adding the file is likely to add it to the
# group that mirrors the filesystem hierarchy rather than back into its
# original position. So far this approach has been acceptable because there's
# nothing of value in these aliasing folders. Should this change we'll have to
# revisit.
class GroupDiffer
  def initialize(dir_lister)
    @dir_lister = dir_lister
    @dirs = {}

    @diff = Diff.new()
  end

  # Finds all files on the filesystem contained within the paths of the given
  # groups and computes a list of DiffEntries describing the state of the
  # files.
  #
  # Args:
  # - groups: A list of PBXGroup objects representing folder groups within the
  #   project that contain files of interest.
  #
  # Returns:
  # A hash of Pathname to DiffEntry objects, one for each file found. If the
  # file exists on the filesystem, :in_source will be true. If the file exists
  # in the project :in_target will be true and :ref will be set to the
  # PBXFileReference naming the file.
  def diff(groups)
    groups.each do |group|
      diff_project_files(group)
    end

    return @diff
  end

  private
  # Recursively traverses all the folder groups in the Xcode project and finds
  # files both on the filesystem and the group file listing.
  def diff_project_files(group)
    find_fs_files(group.real_path)

    group.groups.each do |child|
      diff_project_files(child)
    end

    group.files.each do |file_ref|
      path = file_ref.real_path
      entry = @diff.track(path)
      entry.in_target = true
      entry.ref = file_ref

      if path.file?
        entry.in_source = true
      end
    end
  end

  def find_fs_files(parent_path)
    # Avoid re-traversing the filesystem
    if @dirs.has_key?(parent_path)
      return
    end
    @dirs[parent_path] = true

    @dir_lister.entries(parent_path).each do |path|
      if path.directory?
        find_fs_files(path)
        next
      end

      entry = @diff.track(path)
      entry.in_source = true
    end
  end
end


# Finds files on the filesystem while ignoring files that have been declared to
# be ignored.
class DirectoryLister
  def initialize(root_dir)
    @root_dir = root_dir
    @ignore_basenames = ['.', '..']
    @ignore_pathnames = []
  end

  def add_patterns(patterns)
    patterns.each do |pattern|
      if File.basename(pattern) != pattern
        @ignore_pathnames.push(File.join(@root_dir, pattern))
      else
        @ignore_basenames.push(pattern)
      end
    end
  end

  # Finds filesystem entries that are immediate children of the given Pathname,
  # ignoring files that match the global ignore_files patterns.
  def entries(path)
    result = []
    return result if not path.exist?

    path.entries.each do |entry|
      next if ignore_basename?(entry)

      file = path.join(entry)
      next if ignore_pathname?(file)

      result.push(file)
    end
    return result
  end

  def ignore_basename?(basename)
    @ignore_basenames.each do |ignore|
      if basename.fnmatch(ignore)
        return true
      end
    end
    return false
  end

  def ignore_pathname?(file)
    @ignore_pathnames.each do |ignore|
      if file.fnmatch(ignore)
        return true
      end
    end
    return false
  end
end


if __FILE__ == $0
  main()
end
