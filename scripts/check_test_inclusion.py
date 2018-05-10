#!/bin/python

"""
Verifies that all tests are a part of the project file.
"""

from __future__ import print_function
import os
import os.path
import re
import sys


# Tests that are known not to compile in Xcode and can't be added there.
EXCLUDED = frozenset([
    # b/79496027
    'Firestore/core/test/firebase/firestore/remote/serializer_test.cc',
])


def Main(args):
    problems = CheckProject('Firestore/Example/Firestore.xcodeproj/project.pbxproj',
                            'Firestore/Example/Tests', 'Firestore/core/test')

    problems = FilterProblems(problems)
    problems.sort()

    if len(problems) > 0:
        Error('Test files exist that are unreferenced in Xcode project files:')
        for problem in problems:
            Error(problem)
        sys.exit(1)

    sys.exit(0)


def CheckProject(project_file, *test_dirs):
    test_files = FindTestFiles(*test_dirs)
    basenames = MakeBasenames(test_files)

    file_list_pattern = re.compile(r'/\* (\S+) in Sources \*/')
    with open(project_file, 'r') as fd:
        for line in fd:
            line = line.rstrip()
            m = file_list_pattern.search(line)
            if m:
                basename = m.group(1)
                if basename in basenames:
                    del basenames[basename]

    return sorted(basenames.values())


def FindTestFiles(*srcroots):
    result = []
    for srcroot in srcroots:
        for root, dirs, files in os.walk(srcroot):
            for file in files:
                result.append(os.path.join(root, file))
    return result


def MakeBasenames(filenames):
    test_file_pattern = re.compile(r'(?:Tests?\.mm?|_test\.(?:cc|mm))$')
    result = dict()
    for filename in filenames:
        basename = os.path.basename(filename)
        m = test_file_pattern.search(basename)
        if m:
            result[basename] = filename

    return result


def FilterProblems(problems):
    result = []
    for problem in problems:
        if problem not in EXCLUDED:
            result.append(problem)
    return result


def Error(message, *args):
    message = message % args
    print(message, file=sys.stderr)


if __name__ == '__main__':
    Main(sys.argv[1:])
