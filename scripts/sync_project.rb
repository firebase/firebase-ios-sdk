#!/usr/bin/ruby

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

require 'pathname'

# Note that xcodeproj 1.5.8 appears to be broken
# https://github.com/CocoaPods/Xcodeproj/issues/572
gem 'xcodeproj', '!= 1.5.8'
require 'xcodeproj'


def main()
  # Make all filenames relative to the project root.
  Dir.chdir(File.join(File.dirname(__FILE__), '..'))

  sync_firestore()
end


def sync_firestore()
  project = Xcodeproj::Project.open('Firestore/Example/Firestore.xcodeproj')

  # Enable warnings after opening the project to avoid the warnings in
  # xcodeproj itself
  $VERBOSE = true

  s = Syncer.new(project, Dir.pwd)

  # Files on the filesystem that should be ignored.
  s.ignore_files = [
    'CMakeLists.txt',
    'InfoPlist.strings',
    '*.plist',
  ]

  # Folder groups in the Xcode project that contain tests.
  s.test_groups = [
    'Tests',
    'CoreTests',
    'CoreTestsProtos',
    'SwiftTests',
  ]

  s.target 'Firestore_Tests_iOS' do |t|
    t.source_files = [
      'Firestore/Example/Tests/**',
      'Firestore/core/test/**',
      'Firestore/Protos/cpp/**',
      'Firestore/third_party/Immutable/Tests/**',
    ]
    t.exclude_files = [
      # needs to be in project but not in target
      'Firestore/Example/Tests/Tests-Info.plist',

      # These files are integration tests, handled below
      'Firestore/Example/Tests/Integration/**',
    ]
  end

  s.target 'Firestore_IntegrationTests_iOS' do |t|
    t.source_files = [
      'Firestore/Example/Tests/Integration/**',
      'Firestore/Example/Tests/Util/FSTEventAccumulator.mm',
      'Firestore/Example/Tests/Util/FSTHelpers.mm',
      'Firestore/Example/Tests/Util/FSTIntegrationTestCase.mm',
      'Firestore/Example/Tests/Util/XCTestCase+Await.mm',
      'Firestore/Example/Tests/en.lproj/InfoPlist.strings',
    ]
  end

  s.sync()
  sort_project(project)
  if project.dirty?
    project.save()
  end
end


# The definition of a test target including the target name, its source_files
# and exclude_files. A file is considered part of a target if it matches a
# pattern in source_files but does not match a pattern in exclude_files.
class TargetDef
  def initialize(name)
    @name = name
    @source_files = []
    @exclude_files = []
  end

  attr_accessor :name, :source_files, :exclude_files

  # Returns true if the given relative_path matches this target's source_files
  # but not its exclude_files.
  #
  # Args:
  # - relative_path: a Pathname instance with a path relative to the project
  #   root.
  def matches?(relative_path)
    return matches_patterns(relative_path, @source_files) &&
      !matches_patterns(relative_path, @exclude_files)
  end

  private
  # Evaluates the relative_path against the given list of fnmatch patterns.
  def matches_patterns(relative_path, patterns)
    patterns.each do |pattern|
      if relative_path.fnmatch?(pattern)
        return true
      end
    end
    return false
  end
end


class Syncer
  def initialize(project, root_dir)
    @project = project
    @root_dir = Pathname.new(root_dir)

    @finder = DirectoryLister.new(@root_dir)

    @seen_groups = {}

    @test_groups = []
    @targets = []
  end

  # Considers the given fnmatch glob patterns to be ignored by the syncer.
  # Patterns are matched both against the basename and project-relative
  # qualified pathname.
  def ignore_files=(patterns)
    @finder.add_patterns(patterns)
  end

  # Names the groups within the project that serve as roots for tests within
  # the project.
  def test_groups=(groups)
    @test_groups = []
    groups.each do |group|
      project_group = @project[group]
      if project_group.nil?
        raise "Project does not contain group #{group}"
      end
      @test_groups.push(@project[group])
    end
  end

  # Starts a new target block. Creates a new TargetDef and yields it.
  def target(name, &block)
    t = TargetDef.new(name)
    @targets.push(t)

    block.call(t)
  end

  # Synchronizes the filesystem with the project.
  #
  # Generally there are three separate ways a file is referenced within a project:
  #
  #  1. The file must be in the global list of files, assigning it a UUID.
  #  2. The file must be added to folder groups, describing where it is in the
  #     folder view of the Project Navigator.
  #  3. The file must be added to a target descrbing how it's built.
  #
  # The Xcodeproj library handles (1) for us automatically if we do (2).
  #
  # Synchronization essentially proceeds in two steps:
  #
  #  1. Sync the filesystem structure with the folder group structure. This has
  #     the effect of bringing (1) and (2) into sync.
  #  2. Sync the global list of files with the targets.
  def sync()
    group_differ = GroupDiffer.new(@finder)
    group_diffs = group_differ.diff(@test_groups)
    sync_groups(group_diffs)

    @targets.each do |target_def|
      sync_target(target_def)
    end
  end

  private
  def sync_groups(diff_entries)
    diff_entries.each do |entry|
      if !entry.in_source && entry.in_target
        remove_from_project(entry.ref)
      end

      if entry.in_source && !entry.in_target
        add_to_project(entry.path)
      end
    end
  end

  # Removes the given file reference from the project after the file is found
  # missing but references to it still exist in the project.
  def remove_from_project(file_ref)
    group = file_ref.parents[-1]

    mark_change_in_group(relative_path(group))
    puts "  #{basename(file_ref)} - removed"

    # If the file is gone, any build phase that refers to must also remove the
    # file. Without this, the project will have build file references that
    # contain no actual file.
    @project.native_targets.each do |target|
      target.build_phases.each do |phase|
        if phase.include?(file_ref)
          phase.remove_file_reference(file_ref)
        end
      end
    end

    file_ref.remove_from_project
  end

  # Adds the given file to the project, in a path starting from the test root
  # that fully prefixes the file.
  def add_to_project(path)
    root_group = find_test_group_containing(path)

    # Find or create the group to contain the path.
    dir_rel_path = path.relative_path_from(root_group.real_path).dirname
    group = root_group.find_subpath(dir_rel_path.to_s, true)

    mark_change_in_group(relative_path(group))

    file_ref = group.new_file(path.to_s)

    puts "  #{basename(file_ref)} - added"
    return file_ref
  end

  # Finds a test group whose path prefixes the given entry. Starting from the
  # project root may not work since not all test directories exist within the
  # example app.
  def find_test_group_containing(path)
    @test_groups.each do |group|
      rel = path.relative_path_from(group.real_path)
      next if rel.to_s.start_with?('..')

      return group
    end

    raise "Could not find an existing test group that's a parent of #{entry.path}"
  end

  def mark_change_in_group(group)
    path = group.to_s
    if !@seen_groups.has_key?(path)
      puts "#{path} ..."
      @seen_groups[path] = true
    end
  end

  SOURCES = %w{.c .cc .m .mm}

  def sync_target(target_def)
    target = @project.native_targets.find { |t| t.name == target_def.name }
    if !target
      raise "Missing target #{target_def.name}"
    end

    files = find_files_for_target(target_def)
    sources, resources = classify_files(files)

    sync_build_phase(target, target.source_build_phase, sources)
  end

  def classify_files(files)
    sources = {}
    resources = {}

    files.each do |file|
      path = file.real_path
      ext = path.extname
      if SOURCES.include?(ext)
        sources[path] = file
      end
    end

    return sources, resources
  end

  def sync_build_phase(target, phase, sources)
    # buffer changes to the phase to avoid modifying the array we're iterating
    # over.
    to_remove = []
    phase.files.each do |build_file|
      source_path = build_file.file_ref.real_path
      if sources.has_key?(source_path)
        # matches spec and existing target no action taken
        sources.delete(source_path)

      else
        # in the phase but now missing in the groups
        to_remove.push(build_file)
      end
    end

    to_remove.each do |build_file|
      mark_change_in_group(target.name)

      source_path = build_file.file_ref.real_path
      puts "  #{relative_path(source_path)} - removed"
      phase.remove_build_file(build_file)
    end

    sources.each do |path, file_ref|
      mark_change_in_group(target.name)

      phase.add_file_reference(file_ref)
      puts "  #{relative_path(file_ref)} - added"
    end
  end

  def find_files_for_target(target_def)
    result = []

    @project.files.each do |file_ref|
      next if file_ref.source_tree != '<group>'

      rel = relative_path(file_ref)
      if target_def.matches?(rel)
        result.push(file_ref)
      end
    end
    return result
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
    file_ref = normalize_to_pathname(file_ref)
    return file_ref.relative_path_from(@root_dir)
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
end


# Diffs folder groups against the filesystem directories referenced by those
# folder groups.
#
# This performs the diff starting from the directories referenced by the test
# groups in the project, finding files contained within them. When comparing
# the files it finds against the project this acts on absolute paths to avoid
# problems with arbitary additional groupings in project structure that are
# standard, e.g. "Supporting Files" or "en.lproj" which either act as aliases
# for the parent or are folders that are omitted from the project view.
# Processing the diff this way allows these warts to be tolerated, even if they
# won't necessarily be recreated if an artifact is added to the filesystem.
class GroupDiffer
  def initialize(dir_lister)
    @dir_lister = dir_lister

    @entries = {}
    @dirs = {}
  end

  # Finds all tests on the filesystem contained within the paths of the given
  # test groups and computes a list of DiffEntries describing the state of the
  # files.
  #
  # Args:
  # - groups: A list of PBXGroup objects representing folder groups within the
  #   project that contain tests.
  #
  # Returns:
  # A list of DiffEntry objects, one for each test found. If the test exists on
  # the filesystem, :in_source will be true. If the test exists in the project
  # :in_target will be true and :ref will be set to the PBXFileReference naming
  # the file.
  def diff(groups) groups.each do |group| diff_project_files(group) end

    return @entries.values.sort { |a, b| a.path.basename <=> b.path.basename }
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
      entry = track_file(path)
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

      entry = track_file(path)
      entry.in_source = true
    end
  end

  def track_file(path)
    if @entries.has_key?(path)
      return @entries[path]
    end

    entry = DiffEntry.new(path)
    @entries[path] = entry
    return entry
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
  # ignoring files that match the the global ignore_files patterns.
  def entries(path)
    result = []
    path.entries.each do |entry|
      next if ignore_basename?(entry)

      file = path.join(entry)
      next if ignore_pathname?(file)

      result.push(file)
    end
    return result
  end

  private
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
