include(FindPackageHandleStandardArgs)

set(BINARY_DIR ${FIREBASE_INSTALL_DIR}/external/nanopb)

find_path(
  NANOPB_INCLUDE_DIR pb.h
  HINTS ${BINARY_DIR}/src/nanopb
)

find_library(
  NANOPB_LIBRARY
  NAMES protobuf-nanopb protobuf-nanopbd
  HINTS ${BINARY_DIR}/src/nanopb
)

find_package_handle_standard_args(
  nanopb
  DEFAULT_MSG
  NANOPB_INCLUDE_DIR
  NANOPB_LIBRARY
)

if(NANOPB_FOUND)
  set(NANOPB_INCLUDE_DIRS ${NANOPB_INCLUDE_DIR})

  if (NOT TARGET nanopb)
    add_library(nanopb UNKNOWN IMPORTED)
    set_target_properties(
      nanopb PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES ${NANOPB_INCLUDE_DIRS}
      IMPORTED_LOCATION ${NANOPB_LIBRARY}
    )
  endif()
endif(NANOPB_FOUND)
