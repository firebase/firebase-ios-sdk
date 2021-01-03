objc_library(
    name = "testserver",
    srcs = glob(["**/*.m"]),
    hdrs = glob(["**/*.h"]),
    data = [
        "bigDownloadFile",
        "smallDownloadFile",
    ],
    visibility = ["//visibility:public"],
    deps = ["//third_party/objective_c/GCDWebServer"],
)
