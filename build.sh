#!/bin/bash
#
#    Fennec build scripts
#    Copyright (C) 2020-2024  Matías Zúñiga, Andrew Nayenko, Tavi
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

set -e

# shellcheck source=paths.sh
source "$(dirname "$0")/paths.sh"

# We publish the artifacts into a local Maven repository instead of using the
# auto-publication workflow because the latter does not work for Gradle
# plugins (Glean).

# Set up Android SDK
sdkmanager 'build-tools;36.0.0' # for GeckoView
sdkmanager 'platforms;android-36' # for GeckoView
sdkmanager 'ndk;28.0.13004108' # for Application Services

# Set up Rust
# shellcheck disable=SC1090,SC1091
source "$HOME/.cargo/env"
cargo install --force --vers 0.29.0 cbindgen

# Build LLVM
pushd "$llvm"
llvmtarget=$(cat "$llvm/targets_to_build")
cmake -S llvm -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=out -DCMAKE_C_COMPILER=clang-16 \
    -DCMAKE_CXX_COMPILER=clang++-16 -DLLVM_ENABLE_PROJECTS="clang" -DLLVM_TARGETS_TO_BUILD="$llvmtarget" \
    -DLLVM_USE_LINKER=lld -DLLVM_BINUTILS_INCDIR=/usr/include -DLLVM_ENABLE_PLUGINS=FORCE_ON \
    -DLLVM_DEFAULT_TARGET_TRIPLE="x86_64-unknown-linux-gnu"
cmake --build build -j"$(nproc)"
cmake --build build --target install -j"$(nproc)"
popd

# Build WASI SDK
pushd "$wasi"
mkdir -p build/install/wasi
touch build/compiler-rt.BUILT # fool the build system
make \
    PREFIX=/wasi \
    build/wasi-libc.BUILT \
    build/libcxx.BUILT \
    -j"$(nproc)"
popd

# Build microG libraries
pushd "$gmscore"
gradle -x javaDocReleaseGeneration \
    :play-services-ads-identifier:publishToMavenLocal \
    :play-services-base:publishToMavenLocal \
    :play-services-basement:publishToMavenLocal \
    :play-services-fido:publishToMavenLocal \
    :play-services-tasks:publishToMavenLocal
popd

pushd "$glean"
export TARGET_CFLAGS=-DNDEBUG
gradle publishToMavenLocal
popd

pushd "$glean_as"
gradle publishToMavenLocal
popd

pushd "$application_services"
export NSS_DIR="$application_services/libs/desktop/linux-x86-64/nss"
export NSS_STATIC=1
./libs/verify-android-environment.sh
gradle :tooling-nimbus-gradle:publishToMavenLocal
popd

pushd "$mozilla_release"
./mach build
./mach package
read -ra locales < "$patches/locales"
./mach package-multi-locale --locales "${locales[@]}"
MOZ_CHROME_MULTILOCALE=${locales[*]}
export MOZ_CHROME_MULTILOCALE
gradle -x javadocRelease :geckoview:publishReleasePublicationToMavenLocal
gradle -x javadocRelease :exoplayer2:publishReleasePublicationToMavenLocal
popd

pushd "$android_components"
# Publish concept-fetch (required by A-S) with auto-publication disabled,
# otherwise automatically triggered publication of A-S will fail
gradle :components:concept-fetch:publishToMavenLocal
# Enable the auto-publication workflow now that concept-fetch is published
echo "autoPublish.application-services.dir=$application_services" >> local.properties
gradle publishToMavenLocal
popd

pushd "$fenix"
gradle assembleRelease
popd
