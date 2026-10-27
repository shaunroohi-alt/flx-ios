#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
"${CXX:-c++}" -std=c++17 -Wall -Wextra -Werror -O1 -g -pthread \
  -fsanitize=address,undefined -fno-omit-frame-pointer \
  FLX/Audio/FLXKernel.cpp Tests/KernelTests.cpp -o .build/kernel-tests
ASAN_OPTIONS="${ASAN_OPTIONS:-detect_leaks=1}" .build/kernel-tests
