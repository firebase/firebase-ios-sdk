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

include(FindPackageHandleStandardArgs)

find_path(
  FIREBASE_CPP_SDK_DIR include/firebase/future.h
  HINTS
    $ENV{FIREBASE_CPP_SDK_DIR}
    ${FIREBASE_BINARY_DIR}/external/src/firebase_cpp_sdk
)

find_path(
  FIREBASE_CPP_INCLUDE_DIR firebase/future.h
  PATHS
    ${FIREBASE_CPP_SDK_DIR}/include
)

if(APPLE)
  if("${CMAKE_OSX_SYSROOT}" MATCHES "iphoneos")
    # iOS
    set(FIREBASE_CPP_LIB_DIR ${FIREBASE_CPP_SDK_DIR}/libs/ios/${CMAKE_SYSTEM_PROCESSOR})
  else()
    set(FIREBASE_CPP_LIB_DIR ${FIREBASE_CPP_SDK_DIR}/libs/darwin/universal)
  endif()

elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
  set(FIREBASE_CPP_LIB_DIR ${FIREBASE_CPP_SDK_DIR}/libs/linux/${CMAKE_SYSTEM_PROCESSOR})

elseif(MSVC)
  set(MSVC_VS_VERSION VS2015)

  # Windows runtime mode, either MD or MT depending on whether you are using
  # /MD or /MT. For more information see:
  # https://msdn.microsoft.com/en-us/library/2kzt1wy3.aspx
  set(MSVC_RUNTIME_MODE MD)

  if(${CMAKE_CL_64})
    set(MSVC_CPU x64)
  else()
    set(MSVC_CPU x86)
  endif()

  if(CMAKE_BUILD_TYPE EQUAL Release)
    set(MSVC_CONFIG Release)
  else()
    set(MSVC_CONFIG Debug)
  endif()

  set(
    FIREBASE_CPP_LIB_DIR
    ${FIREBASE_CPP_SDK_DIR}/libs/windows/${MSVC_VS_VERSION}/${MSVC_RUNTIME_MODE}/${MSVC_CPU}/${MSVC_CONFIG}
  )

else()
  message("Unknown platform for the firebase_cpp_sdk.")
  message("")
  message("  CMAKE_SYSTEM_NAME = ${CMAKE_SYSTEM_NAME}")
  message("  CMAKE_SYSTEM_PROCESSOR = ${CMAKE_SYSTEM_PROCESSOR}")
  message("")
endif()

find_library(
  FIREBASE_CPP_APP_LIBRARY
  NAMES firebase_app
  HINTS
    ${FIREBASE_CPP_LIB_DIR}
)

find_package_handle_standard_args(
  firebase_cpp_sdk
  DEFAULT_MSG
  FIREBASE_CPP_INCLUDE_DIR
  FIREBASE_CPP_APP_LIBRARY
)

if(FIREBASE_CPP_SDK_FOUND)
  set(FIREBASE_CPP_INCLUDE_DIRS ${FIREBASE_CPP_INCLUDE_DIR})

  if (NOT TARGET firebase_app)
    add_library(firebase_app UNKNOWN IMPORTED)
    set_target_properties(
      firebase_app PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES ${FIREBASE_CPP_INCLUDE_DIRS}
      IMPORTED_LOCATION ${FIREBASE_CPP_APP_LIBRARY}
    )
  endif()
endif(FIREBASE_CPP_SDK_FOUND)
