include(ExternalProject)
include(ExternalProjectFlags)

ExternalProject_GitSource(
  NANOPB_GIT
  GIT_REPOSITORY "https://github.com/nanopb/nanopb.git"
  GIT_TAG "0.3.9"
)

ExternalProject_Add(
  nanopb
  DEPENDS
    leveldb  # for sequencing

  ${NANOPB_GIT}

  PREFIX ${PROJECT_BINARY_DIR}/external/nanopb

  CMAKE_ARGS
    -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
    -DBUILD_SHARED_LIBS:BOOL=OFF

  BUILD_COMMAND
    ${CMAKE_COMMAND} --build . --target protobuf-nanopb
# COMMAND
#   ${CMAKE_COMMAND} --build . --target something-else
)
