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
sdkmanager 'build-tools;36.1.0' # for GeckoView
sdkmanager 'platforms;android-36.1' # for GeckoView

# Set up Rust
cargo install --force --vers 0.29.2 cbindgen

# Build LLVM
pushd "$llvm"
llvmtarget=$(cat "$llvm/targets_to_build")
cmake -S llvm -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=out -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ -DLLVM_ENABLE_PROJECTS="clang" -DLLVM_TARGETS_TO_BUILD="$llvmtarget" \
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

pushd "$mozilla_release"
./mach build
./mach package
read -ra locales < "$patches/locales"
./mach package-multi-locale --locales "${locales[@]}"
MOZ_CHROME_MULTILOCALE=${locales[*]}
export MOZ_CHROME_MULTILOCALE
gradle -x javadocRelease :geckoview:publishReleasePublicationToMavenLocal
popd

pushd "$android_components"
# Required by A-S
gradle :components:concept-fetch:publishToMavenLocal
# Required by UnifiedPush
gradle :components:concept-base:publishToMavenLocal
gradle :components:support-base:publishToMavenLocal
gradle :components:ui-icons:publishToMavenLocal
popd

pushd "$application_services"
export NSS_DIR="$application_services/libs/desktop/linux-x86-64/nss"
export NSS_STATIC=1
./libs/verify-android-environment.sh
gradle publishToMavenLocal
# Build and install nimbus-fml manually
pushd components/support/nimbus-fml
cargo build --release
popd
mv target/release/nimbus-fml "$mozilla_release/obj/dist/host/bin/nimbus-fml"
popd

pushd "$unifiedpush_ac"
gradle publishToMavenLocal
popd

pushd "$android_components"
gradle publishToMavenLocal
popd

pushd "$fenix"
gradle assembleRelease
popd
