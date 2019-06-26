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

require 'cocoapods'
require 'fileutils'
require 'pathname'
require 'set'

PLATFORM = :osx

def usage()
  script = File.basename($0)
  STDERR.puts <<~EOF
  USAGE: #{script} podspec cmake-file [subspecs...]
  EOF
end

def main(args)
  if args.size < 2 then
    usage()
    exit(1)
  end

  process(*args)
end

# A CMake command, like add_library. The command name is stored in the first
# argument.
class CMakeCommand
  # Create the command with its initial identifying arguments.
  def initialize(*args)
    @args = args
    @checked_count = 0
  end

  def name()
    return @args[0]
  end

  def rest()
    return @args[1..-1]
  end

  def skip?()
    return @checked_count == 0
  end

  def allow_missing_args()
    @checked_count = nil
  end

  # Adds the given arguments to the end of the command
  def add_args(*args)
    args = args.flatten

    unless @checked_count.nil?
      @checked_count += args.size
    end

    args.each do |arg|
      unless @args.include?(arg)
        @args.push(arg)
      end
    end
  end
end

# A model of a macOS or iOS Framework and the CMake commands required to build
# it.
class Framework
  def initialize(name)
    @name = name
    @add_library = CMakeCommand.new('add_library', @name, 'STATIC')
    @add_library.allow_missing_args()

    @public_headers = CMakeCommand.new(
      'set_property', 'TARGET', @name, 'PROPERTY', 'PUBLIC_HEADER')

    @properties = []

    @extras = {}
  end

  # Returns all the CMake commands required to build the framework.
  def commands()
    result = [@add_library]
    result.push(@public_headers, *@properties)
    @extras.keys.sort.each do |key|
      result.push(@extras[key])
    end
    return result
  end

  # Adds library sources to the CMake add_library command that declares the
  # library.
  def add_sources(*sources)
    @add_library.add_args(sources)
  end

  # Adds public headers to the Framework
  def add_public_headers(*headers)
    @public_headers.add_args(headers)
  end

  # Sets a target-level CMake property on the library target that declares the
  # framework.
  def set_property(property, *values)
    command = CMakeCommand.new('set_property', 'TARGET', @name, 'PROPERTY', property)
    command.add_args(values)
    @properties.push(command)
  end

  # Adds target-level preprocessor definitions.
  #
  # Args:
  # - type: PUBLIC, PRIVATE, or INTERFACE
  # - values: C preprocessor defintion arguments starting with -D
  def compile_definitions(type, *values)
    extra_command('target_compile_definitions', @name, type)
      .add_args(values)
  end

  # Adds target-level compile-time include path for the preprocessor.
  #
  # Args:
  # - type: PUBLIC, PRIVATE, or INTERFACE
  # - values: directory names, not including a leading -I flag
  def include_directories(type, *dirs)
    extra_command('target_include_directories', @name, type)
      .add_args(dirs)
  end

  # Adds target-level compile-time compiler options that aren't macro
  # definitions or include directories. Link-time options should be added via
  # lib_libraries.
  #
  # Args:
  # - type: PUBLIC, PRIVATE, or INTERFACE
  # - values: compiler flags, e.g. -fno-autolink
  def compile_options(type, *values)
    extra_command('target_compile_options', @name, type)
      .add_args(values)
  end

  # Adds target-level dependencies or link-time compiler options. CMake
  # interprets any quoted string that starts with "-" as an option and anything
  # else as a library target to depend upon.
  #
  # Args:
  # - type: PUBLIC, PRIVATE, or INTERFACE
  # - values: compiler flags, e.g. -fno-autolink
  def link_libraries(type, *dirs)
    extra_command('target_link_libraries', @name, type)
      .add_args(dirs)
  end

  private
  def extra_command(*key_args)
    key = key_args.join('|')
    command = @extras[key]
    if command.nil?
      command = CMakeCommand.new(*key_args)
      @extras[key] = command
    end
    return command
  end
end

# Generates a framework target based on podspec contents. Models the translation
# of a single podspec (and possible subspecs) to a single CMake framework
# target.
class CMakeGenerator

  # Initializes the generator with the given root Pod::Spec and the binary
  # directory for the current CMake configuration.
  #
  # Args:
  # - spec: A root specification, the name of which becomes the name of the
  #   Framework.
  # - path_list: A Pod::Sandbox::PathList used to cache file operations.
  # - cmake_binary_dir: A directory in which additional files may be written.
  def initialize(spec, path_list, cmake_binary_dir)
    @target = Framework.new(spec.name)

    headers_root = File.join(cmake_binary_dir, 'Headers')
    @headers_dir = File.join(headers_root, spec.name)

    @root = spec

    @target.set_property('FRAMEWORK', 'ON')
    @target.set_property('VERSION', spec.version)

    @target.include_directories('PRIVATE', headers_root, @headers_dir)
    @target.link_libraries('PUBLIC', "\"-framework Foundation\"")

    root_dir = Pathname.new(__FILE__).expand_path().dirname().dirname()
    @path_list = Pod::Sandbox::PathList.new(root_dir)
  end

  attr_reader :target

  # Adds information from the given Pod::Spec to the definition of the CMake
  # framework target. Subspecs are not automatically handled.
  #
  # Cocoapods subspecs are not independent libraries--they contribute sources
  # and dependencies to a final single Framework.
  #
  # Args:
  # - spec: A root or subspec that contributes to the final state of the of the
  #   Framework.
  def add_framework(spec)
    spec = spec.consumer(PLATFORM)
    files = Pod::Sandbox::FileAccessor.new(@path_list, spec)
    sources = [
      files.source_files,
      files.public_headers,
      files.private_headers,
    ].flatten
    @target.add_sources(sources)

    add_headers(files, sources)

    add_dependencies(spec)
    add_framework_dependencies(spec)

    @target.compile_options('INTERFACE', '-F${CMAKE_CURRENT_BINARY_DIR}')
    @target.compile_options('PRIVATE', '${OBJC_FLAGS}')

    add_xcconfig('PRIVATE', spec.pod_target_xcconfig)
    add_xcconfig('PUBLIC', spec.user_target_xcconfig)
  end

  private
  # Sets up the framework headers so that compilation can succeed.
  # Xcode/CocoaPods allow for several different include mechanisms to work:
  #
  #   * Unqualified headers, e.g. +#import "FIRLoggerLevel.h"+, typically
  #     resolved via the header map.
  #   * Qualified relative to some source root, e.g.
  #     +#import "Public/FIRLoggerLevel.h"+, typically resolved by an include
  #     path
  #   * Framework imports, e.g. +#import <FirebaseCore/FIRLoggerLevel.h>+,
  #     resolved by a build process that copies headers into the framework
  #     structure.
  #   * Umbrella imports e.g. +#import <FirebaseCore/FirebaseCore.h>+ (which
  #     happens to import all the public headers).
  #
  # CMake's framework support is incomplete. It has no support at all for
  # generating umbrella headers.
  #
  # CMake also does not completely support framework imports. It does work for
  # sources outside the framework that want to build against it, but until the
  # framework has been completely built the headers aren't available in this
  # form. This prevents frameworks from referring to their own code via
  # framework imports.
  #
  # This method cheats by creating a subdirectory in the build results that has
  # symbolic links of all the public headers accessible with the right path.
  # This makes it possible to use framework imports within the framework itself.
  # The parent of this path is then added as a PRIVATE include directory of the
  # target, making it possible for the framework to see itself this way.
  def add_headers(files, sources)
    # CMake-built frameworks don't have a notion of private headers, but they
    # also don't have a notion of umbrella headers, so all framework headers
    # need to be accessed by name. This means that just dumping all the private
    # and public headers into what CMake considers the public headers makes
    # everything work as we expect.
    headers = [
      files.public_headers,
      files.private_headers
    ].flatten

    @target.add_public_headers(headers)

    # Also, link the headers into a directory that looks like a framework layout
    # so that self-references via framework imports work. These *must* be
    # symbolic links, otherwise our usual sloppiness causes file contents to be
    # included multiple times, usually resulting in ambiguity errors.
    FileUtils.mkdir_p(@headers_dir)
    headers.each do |header|
      FileUtils.ln_sf(header, File.join(@headers_dir, File.basename(header)))
    end

    # Simulate header maps by adding include paths for all the directories
    # containing non-public headers.
    hmap_dirs = Set.new()
    sources.each do |source|
      next if File.extname(source) != '.h'
      next if headers.include?(source)

      hmap_dirs.add(File.dirname(source))
    end
    @target.include_directories('PRIVATE', *hmap_dirs.to_a.sort)
  end

  # Account for differences in dependency names between CocoaPods and CMake.
  # Keys should be CocoaPod dependency names and values should be the
  # equivalent CMake library targets.
  DEP_RENAMES = {
    'nanopb' => 'protobuf-nanopb-static'
  }

  # Adds Pod::Spec +dependencies+ as target_link_libraries. Only root-specs are
  # added as dependencies because in the CMake build there can be only one
  # target for the framework.
  def add_dependencies(spec)
    prefix = "#{@root.name}/"
    spec.dependencies.each do |dep|
      # Dependencies on subspecs of this same spec are handled elsewhere.
      next if dep.name.start_with?(prefix)

      name = dep.name.sub(/\/.*/, '')
      name = DEP_RENAMES.fetch(name, name)

      @target.link_libraries('PUBLIC', name)
    end
  end

  # Adds target_link_libraries entries for all the items in the Pod::Spec
  # +frameworks+ attribute.
  def add_framework_dependencies(spec)
    spec.frameworks.each do |framework|
      @target.link_libraries('PUBLIC', "\"-framework #{framework}\"")
    end
  end

  # Mirrors known entries from the xcconfig entries into their equivalents in
  # CMake. This translates OTHER_CFLAGS, GCC_PREPROCESSOR_DEFINITIONS, and
  # HEADER_SEARCH_PATHS.
  #
  # Args:
  # - type: PUBLIC for +pod_user_xcconfig+ or PRIVATE for
  #   +pod_target_xcconfig+.
  # - xcconfig: the hash of xcconfig values.
  def add_xcconfig(type, xcconfig)
    if xcconfig.empty?
      return
    end

    @target.compile_options(type, split(xcconfig['OTHER_CFLAGS']))

    defs = split(xcconfig['GCC_PREPROCESSOR_DEFINITIONS'])
    defs = defs.map { |x| '-D' + x }
    @target.compile_definitions(type, *defs)

    @target.include_directories(type, *split(xcconfig['HEADER_SEARCH_PATHS']))
  end

  # Splits a textual value in xcconfig. Always returns an array, but that array
  # may be empty if the value didn't exist in the podspec.
  def split(value)
    if value.nil?
      return []
    elsif value.kind_of?(String)
      return value.split
    else
      return [value]
    end
  end
end

# Processes a podspec file, translating all the specs within it into cmake file
# describing how to build it.
#
# Args:
# - podspec_file: The filename of the podspec to use as a source.
# - cmake_file: The filename of the cmake script to produce.
# - req_subspecs: Which subspecs to include. If empty, all subspecs are
#   included (which corresponds to CocoaPods behavior. The default_subspec
#   property is not handled.
def process(podspec_file, cmake_file, *req_subspecs)
  root_dir = Pathname.new(__FILE__).expand_path().dirname().dirname()
  path_list = Pod::Sandbox::PathList.new(root_dir)

  spec = Pod::Spec.from_file(podspec_file)

  writer = Writer.new()
  writer.append <<~EOF
  # This file was generated by #{File.basename(__FILE__)}
  # from #{File.basename(podspec_file)}.
  # Do not edit!
  EOF

  cmake_binary_dir = File.expand_path(File.dirname(cmake_file))

  gen = CMakeGenerator.new(spec, path_list, cmake_binary_dir)
  gen.add_framework(spec)

  req_subspecs = normalize_requested_subspecs(spec, req_subspecs)
  req_subspecs = resolve_subspec_deps(spec, req_subspecs)

  spec.subspecs.each do |subspec|
    if req_subspecs.include?(subspec.name)
      gen.add_framework(subspec)
    end
  end

  gen.target.commands.each do |command|
    writer.write(command)
  end

  File.open(cmake_file, 'w') do |fd|
    fd.write(writer.result)
  end
end

# Returns true if test specifications are supported by the current version of
# CocoaPods and the given +spec+ is a test specification.
def test_specification?(spec)
  # CocoaPods 1.3.0 added test specifications.
  if !spec.respond_to?(:test_specification?)
    return false
  end

  return spec.test_specification?
end

# Translates the (possibly empty) list of requested subspecs into the list of
# subspecs to actually include. If +req_subspecs+ is empty, returns all
# subspecs. If non-empty, all subspecs are returned as qualified names, e.g.
# "Logger" may become "GoogleUtilities/Logger".
def normalize_requested_subspecs(spec, req_subspecs)
  if req_subspecs.empty?
    subspecs = spec.subspecs.select { |s| not test_specification?(s) }
    return subspecs.map { |s| s.name }
  else
    return req_subspecs.map do |name|
      if name.include?(?/)
        name
      else
        "#{spec.name}/#{name}"
      end
    end
  end
end

# Expands the list of requested subspecs to include any dependencies within the
# same root subspec. For example, if +req_subspecs+ where
#
#   +["GoogleUtilties/Logger"]+,
#
# the result would be
#
#   +["GoogleUtilties/Logger", "GoogleUtilities/Environment"]+
#
# because Logger depends upon Environment within the same root spec.
def resolve_subspec_deps(spec, req_subspecs)
  prefix = spec.name + '/'

  result = Set.new()
  while !req_subspecs.empty?
    req = req_subspecs.pop
    result.add(req)

    subspec = spec.subspec_by_name(req)
    subspec.dependencies(PLATFORM).each do |dep|
      if dep.name.start_with?(prefix) && !result.include?(dep.name)
        req_subspecs.push(dep.name)
      end
    end
  end

  return result.to_a.sort
end

# Writes CMake commands out to textual form, taking care of line wrapping.
class Writer
  def initialize()
    @last_command = nil
    @result = ""
  end

  attr_reader :result

  def write(command)
    if command.skip?
      return
    end

    if command.name != @last_command
      @result << "\n"
    end
    @last_command = command.name

    single = "#{command.name}(#{command.rest.join(' ')})\n"
    if single.size < 80
      @result << single
    else
      @result << "#{command.name}(\n"
      command.rest.each do |arg|
        @result << "  #{arg}\n"
      end
      @result << ")\n"
    end
  end

  def append(text)
    @result << text
  end
end

main(ARGV)
