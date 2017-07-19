#!/bin/bash
find ./Firebase \
    -name 'third_party' -prune -o \
    -name 'Firebase/Auth' -prune -o \
    -name 'Example/Auth' -prune -o \
    -name 'Firebase/Database' -prune -o \
    -name 'Example/Database' -prune -o \
    -name 'Firebase/Messaging' -prune -o \
    -name 'Example/Messaging' -prune -o \
    -name 'Firebase/Storage' -prune -o \
    -name 'Example/Storage' -prune -o \
    -name '*.[mh]' \
    -not -name '*.pbobjc.*' \
    -exec clang-format -style=file -i '{}' \;
