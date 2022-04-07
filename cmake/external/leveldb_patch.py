# Copyright 2022 Google LLC
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

"""
Modify the CMakeLists.txt from LevelDb to staticly link Snappy compression
support.
"""

import argparse
import dataclasses
import os
import pathlib
from typing import Iterable, Sequence


def main() -> None:
  arg_parser = argparse.ArgumentParser()
  arg_parser.add_argument("--snappy-source-dir", required=True)
  arg_parser.add_argument("--snappy-binary-dir", required=True)
  parsed_args = arg_parser.parse_args()
  del arg_parser
  snappy_source_dir = pathlib.Path(parsed_args.snappy_source_dir)
  snappy_binary_dir = pathlib.Path(parsed_args.snappy_binary_dir)
  del parsed_args

  cmakelists_txt_file = pathlib.Path("CMakeLists.txt")
  with cmakelists_txt_file.open("rt", encoding="utf8") as f:
    lines = tuple(f)

  patcher = CMakeListsPatcher(
    lines,
    os.path.abspath(__file__),
    snappy_source_dir,
    snappy_binary_dir,
  )

  patched_lines = tuple(patcher.patch())

  with cmakelists_txt_file.open("wt", encoding="utf8") as f:
    f.writelines(patched_lines)


@dataclasses.dataclass(frozen=True)
class LineComponents:
  full: str
  indent: str
  line: str
  eol: str


class CMakeListsPatcher:

  SNAPPY_DETECT_LINE = \
    """check_library_exists(snappy snappy_compress "" HAVE_SNAPPY)"""
  SNAPPY_INCLUDE_LINE = \
    "target_include_directories(leveldb"
  SNAPPY_LINK_LINE = \
    "target_link_libraries(leveldb snappy)"

  def __init__(
      self,
      lines: Sequence[str],
      script_name: str,
      snappy_source_dir: pathlib.Path,
      snappy_binary_dir: pathlib.Path) -> None:
    self.i = 0
    self.lines = lines
    self.script_name = script_name
    self.snappy_source_dir_str = snappy_source_dir.as_posix()
    self.snappy_binary_dir_str = snappy_binary_dir.as_posix()

  def patch(self) -> Iterable[str]:
    while self.i < len(self.lines):
      full_line = self.lines[self.i]
      line = self._split_line(full_line)
      self.i += 1

      if line.line == self.SNAPPY_DETECT_LINE:
        yield from self._on_snappy_detect_line(line)
      elif line.line == self.SNAPPY_INCLUDE_LINE:
        yield full_line
        yield from self._on_leveldb_include_start()
      elif line.line == self.SNAPPY_LINK_LINE:
        yield from self._on_leveldb_snappy_link_line(line)
      else:
        yield full_line

  def _begin_mod_line(self, mod_name: str) -> str:
    return f"# BEGIN: {mod_name} modification by {self.script_name}"

  def _end_mod_line(self, mod_name: str) -> str:
    return f"# END: {mod_name} modification by {self.script_name}"

  def _on_snappy_detect_line(self, line: LineComponents) -> Iterable[str]:
    yield self._begin_mod_line("snappy_detect_line") + line.eol
    yield line.indent + "# " + line.line + line.eol
    yield line.indent + """set(HAVE_SNAPPY ON CACHE BOOL "")""" + line.eol
    yield self._end_mod_line("snappy_detect_line") + line.eol

  def _on_leveldb_include_start(self) -> Iterable[str]:
    line1 = self._split_line(self.lines[self.i])
    line2 = self._split_line(self.lines[self.i + 1])
    begin_mod_line = self._begin_mod_line("leveldb_include_start")

    if line1.line == begin_mod_line:
      return

    yield begin_mod_line + line1.eol
    yield line1.indent + "PRIVATE" + line1.eol
    yield line2.indent + self.snappy_source_dir_str + line2.eol
    yield line2.indent + self.snappy_binary_dir_str + line2.eol
    yield self._end_mod_line("leveldb_include_start") + line1.eol

  def _on_leveldb_snappy_link_line(self, line: LineComponents) -> Iterable[str]:
    yield self._begin_mod_line("leveldb_snappy_link_line") + line.eol
    yield line.indent + "# " + line.line + line.eol
    yield line.indent + f"target_link_libraries(leveldb Snappy::Snappy)" + line.eol
    yield self._end_mod_line("leveldb_snappy_link_line") + line.eol

  def _split_line(self, line: str) -> LineComponents:
    line_rstripped = line.rstrip()
    eol = line[len(line_rstripped):]
    line_stripped = line_rstripped.strip()
    indent = line_rstripped[:len(line_rstripped) - len(line_stripped)]
    return LineComponents(full=line, indent=indent, line=line_stripped, eol=eol)


class LeveDbPatchException(Exception):
  pass


if __name__ == "__main__":
  main()
