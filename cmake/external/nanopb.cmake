include(ExternalProject)
include(ExternalProjectFlags)

ExternalProject_GitSource(
  NANOPB_GIT
  GIT_REPOSITORY "https://github.com/nanopb/nanopb.git"
  GIT_TAG "0.3.9"
)

ExternalProject_Add(
  nanopb
  ${NANOPB_GIT}
  PREFIX ${PROJECT_BINARY_DIR}/external/nanopb
)

ExternalProject_Add_Step(
  nanopb
  configure_generator
  DEPENDEES configure
  COMMAND ${CMAKE_COMMAND} -E copy_directory <SOURCE_DIR>/generator <BINARY_DIR>/generator
)

ExternalProject_Add_Step(
  nanopb
  build_generator
  DEPENDEES configure_generator build
  COMMAND make -C <BINARY_DIR>/generator/proto
)
