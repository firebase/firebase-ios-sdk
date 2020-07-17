#!/usr/bin/env python3
#
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
"""Unit tests for check_cmake_includes.py."""

import os
import pathlib
import re
import shutil
import sys
import tempfile
from typing import Iterable, Mapping
import unittest
from unittest import mock

import check_cmake_includes


class CheckCmakeIncludesTestCase(unittest.TestCase):

  def create_temp_file(self, lines: Iterable[str] = tuple()) -> pathlib.Path:
    """Creates a temporary file with the given lines of text.

    The temporary file will be deleted when the test case ends.

    Arguments:
      lines: The lines of text to write to the file.

    Returns:
      The temporary file that was created.
    """
    (handle, path_str) = tempfile.mkstemp()
    os.close(handle)
    self.addCleanup(os.remove, path_str)
    lines = lines if lines is not None else []
    return self.write_lines_to_file(pathlib.Path(path_str), *lines)

  def write_lines_to_file(
      self,
      path: pathlib.Path,
      *lines: str,
  ) -> pathlib.Path:
    """Writes lines of text to a file.

    Arguments:
      path: The file to which the lines will be written.
      lines: The lines of text to write to the file.

    Returns:
      Returns the given path.
    """
    with path.open("wt", encoding="utf8") as f:
      for line in lines:
        print(line, file=f)
    return path

  def create_temp_dir(self) -> pathlib.Path:
    """Creates a temporary directory.

    The directory will be deleted when this test case ends.

    Returns:
      The path of the created directory.
    """
    path_str = tempfile.mkdtemp()
    self.addCleanup(shutil.rmtree, path_str)
    return pathlib.Path(path_str)

  def assert_contains_word(
      self,
      text: str,
      word: str,
      ignore_case: bool = False,
  ) -> None:
    """Asserts that a string contains a "word".

    A "word" must be separated from surrounding text by at least one non-word
    character, or it must be a prefix or suffix of the text.

    Arguments:
      text: The text to verify contains the given word.
      word: The word to verify is part of the given text.
      ignore_case: If False (the default) then perform a case-sensitive search;
        otherwise, if True, the perform a case-insensitie search.
    """
    pattern_prefix = "(?i)" if ignore_case else ""
    pattern = pattern_prefix + r"(\W|^)" + re.escape(word) + r"(\W|$)"
    self.assertRegex(text, pattern)


class ConfigureFileParserTest(CheckCmakeIncludesTestCase):

  def test_init_positional_args(self):
    path = object()

    parser = check_cmake_includes.ConfigureFileParser(path)

    self.assertIs(parser.path, path)

  def test_init_keyword_args(self):
    path = object()

    parser = check_cmake_includes.ConfigureFileParser(path=path)

    self.assertIs(parser.path, path)

  def test_parse_empty_file_returns_empty_defines(self):
    path = self.create_temp_file()
    parser = check_cmake_includes.ConfigureFileParser(path=path)

    parse_result = parser.parse()

    self.assertEqual(parse_result.defines, frozenset())

  def test_parse_file_with_cmakedefines_returns_those_defines(self):
    configure_file_lines = [
        "#cmakedefine SOME_VAR1",
        "#cmakedefine SOME_VAR2 some_value",
        "#cmakedefine   SOME_VAR3 some_value1 some_value2",
    ]
    path = self.create_temp_file(configure_file_lines)
    parser = check_cmake_includes.ConfigureFileParser(path=path)

    parse_result = parser.parse()

    expected_defines = frozenset(["SOME_VAR1", "SOME_VAR2", "SOME_VAR3"])
    self.assertEqual(parse_result.defines, expected_defines)


class CppFileParserTest(CheckCmakeIncludesTestCase):

  def test_init_positional_args(self):
    path = object()

    parser = check_cmake_includes.CppFileParser(path)

    self.assertIs(parser.path, path)

  def test_init_keyword_args(self):
    path = object()

    parser = check_cmake_includes.CppFileParser(path=path)

    self.assertIs(parser.path, path)

  def test_parse_empty_file_returns_empty_result(self):
    path = self.create_temp_file()
    parser = check_cmake_includes.CppFileParser(path=path)

    parse_result = parser.parse()

    self.assert_result(
        parse_result,
        includes=[],
        defines_used={},
    )

  def test_parse(self):
    cpp_file_lines = [
        "#include \"a/b/file_1.h\"", "#include     \"a/b/file_2.h\"",
        "#InCluDe \"file_3.h\"", "#define INTERNAL_DEFINE_1",
        "#define INTERNAL_DEFINE_2 123", "#define   INTERNAL_DEFINE_3 abc",
        "#if VAR1", "#ifdef VAR2", "#ifndef VAR3", "#elif VAR4", "#else",
        "#endif", "#IMadeThisUp VAR_WITH_UNDERSCORES",
        "int main(int argc, char** argv) {", "  return 0;"
        "}"
    ]
    path = self.create_temp_file(cpp_file_lines)
    parser = check_cmake_includes.CppFileParser(path=path)

    parse_result = parser.parse()

    self.assert_result(
        parse_result,
        includes=["a/b/file_1.h", "a/b/file_2.h", "file_3.h"],
        defines_used={
            "VAR1": 7,
            "VAR2": 8,
            "VAR3": 9,
            "VAR4": 10,
            "VAR_WITH_UNDERSCORES": 13,
        },
    )

  def assert_result(
      self,
      parse_result: check_cmake_includes.CppFileParserResult,
      includes: Iterable[str],
      defines_used: Mapping[str, int],
  ) -> None:
    with self.subTest("includes"):
      self.assertEqual(parse_result.includes, frozenset(includes))
    with self.subTest("defines_used"):
      self.assertEqual(parse_result.defines_used, defines_used)


class RequiredIncludesCheckerTest(CheckCmakeIncludesTestCase):

  def test_init_positional_args(self):
    defines = object()

    checker = check_cmake_includes.RequiredIncludesChecker(defines)

    self.assertIs(checker.defines, defines)

  def test_init_keyword_args(self):
    defines = object()

    checker = check_cmake_includes.RequiredIncludesChecker(defines=defines)

    self.assertIs(checker.defines, defines)

  def test_check_file_returns_empty_list_if_defines_is_empty(self):
    lines = ["#if HELLO"]
    path = self.create_temp_file(lines)
    checker = check_cmake_includes.RequiredIncludesChecker(defines={})

    missing_includes = checker.check_file(path)

    self.assertEqual(missing_includes, tuple())

  def test_check_file_returns_empty_list_if_no_missing_includes(self):
    lines = [
        "#include \"file_1.h\"",
        "#include \"a/b/file_2.h\"",
        "#define DEFINED_VAR 1",
        "#if VAR_1",
        "#if  VAR_2",
        "#elif UNSPECIFIED_DEFINE",
    ]
    defines = {
        "VAR_1": "file_1.h",
        "VAR_2": "a/b/file_2.h",
        "UNUSED_VAR": "a/b/unused.h",
    }
    path = self.create_temp_file(lines)
    checker = check_cmake_includes.RequiredIncludesChecker(defines=defines)

    missing_includes = checker.check_file(path)

    self.assertEqual(missing_includes, tuple())

  def test_check_file_returns_the_missing_define(self):
    lines = [
        "#if   VAR1",
        "#elif VAR2",
        "#elif VAR2 again",
        "#ifndef UNSPECIFIED_DEFINE",
    ]
    defines = {
        "VAR1": "file1.h",
        "VAR2": "file2.h",
    }
    path = self.create_temp_file(lines)
    checker = check_cmake_includes.RequiredIncludesChecker(defines=defines)

    missing_includes = checker.check_file(path)

    expected_missing_includes = (
        check_cmake_includes.MissingInclude(
            define="VAR1", include="file1.h", line_number=1),
        check_cmake_includes.MissingInclude(
            define="VAR2", include="file2.h", line_number=2),
    )
    self.assertCountEqual(missing_includes, expected_missing_includes)


class RunTest(CheckCmakeIncludesTestCase):

  def test_no_errors(self):
    cmake_configure_file_lines = [
        "blah blah",
        "#cmakedefine VAR1",
        "#cmakedefine VAR2 1",
        "blah blah",
    ]
    cmake_configure_file = self.create_temp_file(cmake_configure_file_lines)
    source_file_lines = [
        "blah blah",
        "#define ABC",
        "#include \"a/b/c.h\"",
        "#ifdef VAR1",
        "# if  VAR2 zzz",
        "#elif XYZ",
    ]
    source_file = self.create_temp_file(source_file_lines)
    mock_logger = mock.create_autospec(
        check_cmake_includes.Logger, spec_set=True, instance=True)

    num_errors = check_cmake_includes.run(
        cmake_configure_files={cmake_configure_file: "a/b/c.h"},
        source_files=[source_file],
        logger=mock_logger,
    )

    with self.subTest("num_errors"):
      self.assertEqual(num_errors, 0)
    with self.subTest("logger.summary"):
      mock_logger.summary.assert_called_once_with(1, 0)
    with self.subTest("logger.missing_include"):
      mock_logger.missing_include.assert_not_called()

  def test_with_errors(self):
    cmake_configure_file1 = self.create_temp_file([
        "#cmakedefine VAR1",
    ])
    cmake_configure_file2 = self.create_temp_file([
        "#cmakedefine VAR2",
    ])
    valid_source_file1 = self.create_temp_file([
        "#include \"config1.h\"",
        "#include \"config2.h\"",
        "#if VAR1",
        "#if VAR2",
    ])
    valid_source_file2 = self.create_temp_file([
        "#if SOME_OTHER_VAR1",
        "#if SOME_OTHER_VAR2",
    ])
    missing_config1_source_file = self.create_temp_file([
        "#include \"config2.h\"",
        "#if VAR1",
        "#if VAR2",
    ])
    missing_config2_source_file = self.create_temp_file([
        "#include \"config1.h\"",
        "#if VAR1",
        "#if VAR2",
    ])
    missing_config1and2_source_file = self.create_temp_file([
        "#if VAR1",
        "#if VAR2",
    ])
    mock_logger = mock.create_autospec(
        check_cmake_includes.Logger, spec_set=True, instance=True)

    num_errors = check_cmake_includes.run(
        cmake_configure_files={
            cmake_configure_file1: "config1.h",
            cmake_configure_file2: "config2.h",
        },
        source_files=[
            valid_source_file1,
            valid_source_file2,
            missing_config1_source_file,
            missing_config2_source_file,
            missing_config1and2_source_file,
        ],
        logger=mock_logger,
    )

    with self.subTest("num_errors"):
      self.assertEqual(num_errors, 4)
    with self.subTest("logger.summary"):
      mock_logger.summary.assert_called_once_with(5, 4)
    with self.subTest("logger.missing_include call count"):
      self.assertEqual(4, mock_logger.missing_include.call_count)
    with self.subTest("logger.missing_include call 1"):
      mock_logger.missing_include.assert_any_call(
          missing_config1_source_file,
          check_cmake_includes.MissingInclude(
              define="VAR1", include="config1.h", line_number=2))
    with self.subTest("logger.missing_include call 2"):
      mock_logger.missing_include.assert_any_call(
          missing_config2_source_file,
          check_cmake_includes.MissingInclude(
              define="VAR2", include="config2.h", line_number=3))
    with self.subTest("logger.missing_include call 3"):
      mock_logger.missing_include.assert_any_call(
          missing_config1and2_source_file,
          check_cmake_includes.MissingInclude(
              define="VAR1", include="config1.h", line_number=1))
    with self.subTest("logger.missing_include call 4"):
      mock_logger.missing_include.assert_any_call(
          missing_config1and2_source_file,
          check_cmake_includes.MissingInclude(
              define="VAR2", include="config2.h", line_number=2))

  def assert_missing_include_line(
      self,
      line: str,
      source_file: pathlib.Path,
      var_name: str,
      missing_include: str,
      line_number: int,
  ) -> None:
    self.assert_contains_word(line, f"{source_file}:{line_number}")
    self.assert_contains_word(line, var_name)
    self.assert_contains_word(line, missing_include)


class ArgumentParserTest(CheckCmakeIncludesTestCase):

  def setUp(self):
    super().setUp()
    self.parser = check_cmake_includes.ArgumentParser()
    mock.patch.object(
        self.parser.parser,
        "_print_message",
        spec_set=True,
        autospec=True,
    ).start()
    mock.patch.object(
        self.parser.parser,
        "exit",
        spec_set=True,
        autospec=True,
        side_effect=self.mock_argument_parser_exit,
    ).start()

  def test_no_args_should_fail(self):
    with self.assertRaises(self.MockArgparseExitError):
      self.parser.parse_args([])

  def test_source_files_not_specified_should_fail(self):
    with self.assertRaises(self.MockArgparseExitError) as assert_context:
      self.parser.parse_args([
          "--cmake_configure_file=cmake_configure_file.txt",
          "--required_include=required_include.h",
      ])

    exception = assert_context.exception
    self.assertEqual(exception.status, 2)
    self.assertIn("source_files", exception.message)

  def test_cmake_configure_file_not_specified_should_fail(self):
    with self.assertRaises(self.MockArgparseExitError) as assert_context:
      self.parser.parse_args([
          "--required_include=required_include.h",
          "main.cc",
      ])

    exception = assert_context.exception
    self.assertEqual(exception.status, 2)
    self.assertIn("--cmake_configure_file", exception.message)

  def test_required_include_not_specified_should_fail(self):
    with self.assertRaises(self.MockArgparseExitError) as assert_context:
      self.parser.parse_args([
          "--cmake_configure_file=cmake_configure_file.txt",
          "main.cc",
      ])

    exception = assert_context.exception
    self.assertEqual(exception.status, 2)
    self.assertIn("--required_include", exception.message)

  def test_non_existent_source_files_should_be_treated_like_a_file(self):
    temp_dir = self.create_temp_dir()
    non_existent_file = temp_dir / "IDoNotExist.cc"

    parse_result = self.parser.parse_args([
        "--cmake_configure_file=cmake_configure_file.txt",
        "--required_include=required_include.h",
        f"{non_existent_file}",
    ])

    self.assertEqual(parse_result.source_files, [non_existent_file])

  def test_source_files_that_are_files_should_be_returned(self):
    source_file1 = self.create_temp_file()
    source_file2 = self.create_temp_file()
    source_file3 = self.create_temp_file()

    parse_result = self.parser.parse_args([
        "--cmake_configure_file=cmake_configure_file.txt",
        "--required_include=required_include.h",
        f"{source_file1}",
        f"{source_file2}",
        f"{source_file3}",
    ])

    self.assertEqual(parse_result.source_files, [
        source_file1,
        source_file2,
        source_file3,
    ])

  def test_source_files_that_are_directories_should_be_recursed(self):
    source_dir = self.create_temp_dir()
    source_file1 = source_dir / "src1.cc"
    source_file1.touch()
    source_file2 = source_dir / "src2.cc"
    source_file2.touch()
    subdir1 = source_dir / "subdir1"
    subdir1.mkdir()
    source_file3 = subdir1 / "src3.cc"
    source_file3.touch()
    source_file4 = subdir1 / "src4.cc"
    source_file4.touch()
    subdir2 = source_dir / "subdir2"
    subdir2.mkdir()
    source_file5 = subdir2 / "src5.cc"
    source_file5.touch()
    source_file6 = subdir2 / "src6.cc"
    source_file6.touch()

    parse_result = self.parser.parse_args([
        "--cmake_configure_file=cmake_configure_file.txt",
        "--required_include=required_include.h",
        f"{source_dir}",
    ])

    self.assertCountEqual(parse_result.source_files, [
        source_file1,
        source_file2,
        source_file3,
        source_file4,
        source_file5,
        source_file6,
    ])

  def test_filename_includes_are_respected(self):
    source_dir = self.create_temp_dir()
    source_file1 = source_dir / "src.cc"
    source_file1.touch()
    source_file2 = source_dir / "src.h"
    source_file2.touch()
    source_file3 = source_dir / "src.txt"
    source_file3.touch()
    source_file4 = source_dir / "src.h.in"
    source_file4.touch()
    source_file5 = source_dir / "wwXzz"
    source_file5.touch()
    source_file6 = source_dir / "wwYzz"
    source_file6.touch()

    parse_result = self.parser.parse_args([
        "--cmake_configure_file=cmake_configure_file.txt",
        "--required_include=required_include.h",
        "--filename_include=*.cc",
        "--filename_include=*.h",
        "--filename_include=*[XY]*",
        f"{source_dir}",
    ])

    self.assertCountEqual(parse_result.source_files, [
        source_file1,
        source_file2,
        source_file5,
        source_file6,
    ])

  def test_fewer_cmake_configure_files_than_required_includes(self):
    with self.assertRaises(self.MockArgparseExitError) as assert_context:
      self.parser.parse_args([
          "--cmake_configure_file=cmake_configure_file1.txt",
          "--required_include=required_include1.h",
          "--required_include=required_include2.h",
          "main.cc",
      ])

    exception = assert_context.exception
    self.assertEqual(exception.status, 2)
    self.assertIn("--required_include", exception.message)
    self.assertIn("--cmake_configure_file", exception.message)
    self.assertIn(" 2 ", exception.message)
    self.assertIn(" 1 ", exception.message)

  def test_more_cmake_configure_files_than_required_includes(self):
    with self.assertRaises(self.MockArgparseExitError) as assert_context:
      self.parser.parse_args([
          "--cmake_configure_file=cmake_configure_file1.txt",
          "--cmake_configure_file=cmake_configure_file2.txt",
          "--cmake_configure_file=cmake_configure_file3.txt",
          "--required_include=required_include1.h",
          "main.cc",
      ])

    exception = assert_context.exception
    self.assertEqual(exception.status, 2)
    self.assertIn("--required_include", exception.message)
    self.assertIn("--cmake_configure_file", exception.message)
    self.assertIn(" 3 ", exception.message)
    self.assertIn(" 1 ", exception.message)

  def test_cmake_configure_files_and_required_includes(self):
    parse_result = self.parser.parse_args([
        "--cmake_configure_file=cmake_configure_file1.txt",
        "--cmake_configure_file=cmake_configure_file2.txt",
        "--required_include=required_include1.h",
        "--required_include=required_include2.h",
        "main.cc",
    ])

    self.assertEqual(
        parse_result.cmake_configure_files, {
            pathlib.Path("cmake_configure_file1.txt"): "required_include1.h",
            pathlib.Path("cmake_configure_file2.txt"): "required_include2.h",
        })

  def test_quiet_mode_default_value(self):
    parse_result = self.parser.parse_args([
        "--cmake_configure_file=cmake_configure_file.txt",
        "--required_include=required_include.h",
        "main.cc",
    ])

    self.assertFalse(parse_result.logger.quiet_mode)

  def test_quiet_mode_specified(self):
    parse_result = self.parser.parse_args([
        "--cmake_configure_file=cmake_configure_file.txt",
        "--required_include=required_include.h",
        "--quiet",
        "main.cc",
    ])

    self.assertTrue(parse_result.logger.quiet_mode)

  class MockArgparseExitError(Exception):
    """Exception raised by the mocked ArgumentParser methods."""

    def __init__(self, status, message):
      super().__init__(f"status={status} message={message}")
      self.status = status
      self.message = message

  def mock_argument_parser_exit(self, status=0, message=None):
    raise self.MockArgparseExitError(status, message)


class MainTest(CheckCmakeIncludesTestCase):

  def setUp(self):
    super().setUp()

    sys_patcher = mock.patch.object(sys, "argv")
    sys_patcher.start()
    self.addCleanup(sys_patcher.stop)

    logger_patcher = mock.patch.object(
        check_cmake_includes,
        "Logger",
        spec_set=True,
        autospec=True,
    )
    logger_patcher.start()
    self.addCleanup(logger_patcher.stop)

  def test_no_errors(self):
    root_dir = self.create_temp_dir()
    src_dir = root_dir / "src"
    src_dir.mkdir()
    include_dir = root_dir / "include"
    include_dir.mkdir()
    config_h_in_file = self.write_lines_to_file(
        include_dir / "config.h.in",
        "#cmakedefine VAR1",
        "#cmakedefine VAR2",
    )
    self.write_lines_to_file(
        src_dir / "file1.cc",
        "#include \"config.h\"",
        "#if VAR1",
    )
    self.write_lines_to_file(
        src_dir / "file2.cc",
        "#include \"config.h\"",
        "#if VAR2",
    )
    self.write_lines_to_file(
        src_dir / "ignore_me.txt",
        "// The line below would be an error if scanned.",
        "#if VAR2",
    )
    sys.argv = [
        "prog.py",
        f"--cmake_configure_file={config_h_in_file}",
        "--required_include=config.h",
        "--filename_include=*.cc",
        f"{root_dir}",
    ]

    exit_code = check_cmake_includes.main()

    self.assertEqual(exit_code, 0)

  def test_with_errors(self):
    root_dir = self.create_temp_dir()
    config_h_in_file = self.write_lines_to_file(
        root_dir / "config.h.in",
        "#cmakedefine VAR1",
        "#cmakedefine VAR2",
    )
    self.write_lines_to_file(root_dir / "file1.cc", "#if VAR1")
    self.write_lines_to_file(root_dir / "file2.cc", "#if VAR2")
    sys.argv = [
        "prog.py",
        f"--cmake_configure_file={config_h_in_file}",
        "--required_include=config.h",
        "--filename_include=*.cc",
        f"{root_dir}",
    ]

    exit_code = check_cmake_includes.main()

    self.assertEqual(exit_code, 1)


class LoggerTest(CheckCmakeIncludesTestCase):

  def test_init_positional_args(self):
    quiet_mode = object()

    logger = check_cmake_includes.Logger(quiet_mode)

    self.assertIs(quiet_mode, logger.quiet_mode)

  def test_init_keyword_args(self):
    quiet_mode = object()

    logger = check_cmake_includes.Logger(quiet_mode=quiet_mode)

    self.assertIs(quiet_mode, logger.quiet_mode)

  def test_missing_include(self):
    logger = check_cmake_includes.Logger(quiet_mode=False)
    source_file = pathlib.Path("test.cc")
    missing_include = check_cmake_includes.MissingInclude(
        define="VAR", include="config.h", line_number=42)
    log_patcher = mock.patch.object(logger, "log", spec_set=True, autospec=True)

    with log_patcher as mock_log:
      logger.missing_include(source_file, missing_include)

    mock_log.assert_called_once()
    message = mock_log.call_args[0][0]
    self.assert_contains_word(message, f"{source_file}")
    self.assert_contains_word(message, "VAR")
    self.assert_contains_word(message, "config.h")
    self.assert_contains_word(message, "42")

  def test_missing_include_quiet_mode(self):
    logger = check_cmake_includes.Logger(quiet_mode=True)
    source_file = pathlib.Path("test.cc")
    missing_include = check_cmake_includes.MissingInclude(
        define="VAR", include="config.h", line_number=42)
    log_patcher = mock.patch.object(logger, "log", spec_set=True, autospec=True)

    with log_patcher as mock_log:
      logger.missing_include(source_file, missing_include)

    mock_log.assert_called_once()

  def test_summary(self):
    logger = check_cmake_includes.Logger(quiet_mode=False)
    log_patcher = mock.patch.object(logger, "log", spec_set=True, autospec=True)

    with log_patcher as mock_log:
      logger.summary(src_file_count=123, error_count=456)

    mock_log.assert_called_once()
    message = mock_log.call_args[0][0]
    self.assert_contains_word(message, "123")
    self.assert_contains_word(message, "456")

  def test_summary_quiet_mode(self):
    logger = check_cmake_includes.Logger(quiet_mode=True)
    log_patcher = mock.patch.object(logger, "log", spec_set=True, autospec=True)

    with log_patcher as mock_log:
      logger.summary(src_file_count=123, error_count=456)

    mock_log.assert_not_called()


if __name__ == "__main__":
  unittest.main()
