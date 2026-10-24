#!/bin/bash
#
#    Ermine build scripts
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

# Set up Android SDK for GeckoView
sdkmanager 'build-tools;37.0.0'
sdkmanager 'cmdline-tools;23.0'
sdkmanager 'platform-tools;37.0.0'

if [ ! -e /opt/android-sdk/platforms/android-37.2 ]; then
    curl --silent -O https://dl.google.com/android/repository/platform-37.2_r01.zip
    echo '916410633df92a98da56aa7c87a1955f865f4d3b888373660794ef8173f72972  platform-37.2_r01.zip' | shasum -c
    unzip -q platform-37.2_r01.zip
    mkdir -p /opt/android-sdk/platforms/
    mv android-37.2 /opt/android-sdk/platforms/android-37.2
fi

sdkmanager 'ndk;29.0.14206865' # for Glean

# Set up Rust
cargo install --force --vers 0.29.4 cbindgen

# Build LLVM
pushd "$llvm"

triplet=$(cat "$patches/target-triplet.txt")

python3 "$mozilla_release/build/build-clang/build-clang.py" \
    -c "$patches/use-system-clang-19.json" \
    -c "$mozilla_release/build/build-clang/clang-22.json" \
    -c "$patches/stage-1-${triplet%-*-*}.json" \
    --skip-tar

mkdir -p build-compiler-rt
pushd build-compiler-rt
touch libgcc.a # Only needed to pass CMake tests
cmake "$llvm/compiler-rt" \
    -GNinja \
    -DCMAKE_C_COMPILER="$llvm/build/stage1/clang/bin/clang" \
    -DCMAKE_CXX_COMPILER="$llvm/build/stage1/clang/bin/clang++" \
    -DCMAKE_ASM_COMPILER="$llvm/build/stage1/clang/bin/clang" \
    -DCMAKE_AR="$llvm/build/stage1/clang/bin/llvm-ar" \
    -DCMAKE_RANLIB="$llvm/build/stage1/clang/bin/llvm-ranlib" \
    -DCMAKE_C_COMPILER_TARGET="${triplet}26" \
    -DCMAKE_CXX_COMPILER_TARGET="${triplet}26" \
    -DCMAKE_ASM_COMPILER_TARGET="${triplet}26" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$llvm/build/stage1/clang" \
    -DCOMPILER_RT_INSTALL_LIBRARY_DIR:PATH=lib/clang/22/lib \
    -DLLVM_ENABLE_ASSERTIONS=OFF \
    -DLLVM_CONFIG_PATH="$llvm/build/stage1/clang/bin/llvm-config" \
    -DCMAKE_SYSROOT="$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot" \
    -DCMAKE_LINKER="$llvm/build/stage1/clang/bin/lld" \
    -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld --rtlib=libgcc -L$PWD" \
    -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld \
    -DANDROID=1 \
    -DANDROID_NATIVE_API_LEVEL=26 \
    -DSANITIZER_ALLOW_CXXABI=OFF \
    -DLLVM_DEFAULT_TARGET_TRIPLE="${triplet%-*-*}-unknown-linux-android" \
    -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
    -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
    -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
    -DCOMPILER_RT_BUILD_ORC=OFF \
    -DCOMPILER_RT_BUILTINS_HIDE_SYMBOLS=OFF
ninja -v install
popd

mkdir -p build-runtimes
pushd build-runtimes
cmake "$llvm/runtimes" \
    -GNinja \
    -DCMAKE_C_COMPILER="$llvm/build/stage1/clang/bin/clang" \
    -DCMAKE_CXX_COMPILER="$llvm/build/stage1/clang/bin/clang++" \
    -DCMAKE_ASM_COMPILER="$llvm/build/stage1/clang/bin/clang" \
    -DCMAKE_AR="$llvm/build/stage1/clang/bin/llvm-ar" \
    -DCMAKE_RANLIB="$llvm/build/stage1/clang/bin/llvm-ranlib" \
    -DCMAKE_C_COMPILER_TARGET="${triplet}26" \
    -DCMAKE_CXX_COMPILER_TARGET="${triplet}26" \
    -DCMAKE_ASM_COMPILER_TARGET="${triplet}26" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$llvm/build/stage1/clang" \
    -DLLVM_ENABLE_ASSERTIONS=OFF \
    -DLLVM_CONFIG_PATH="$llvm/build/stage1/clang/bin/llvm-config" \
    -DCMAKE_SYSROOT="$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot" \
    -DCMAKE_LINKER="$llvm/build/stage1/clang/bin/lld" \
    -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld \
    -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld \
    -DANDROID=1 \
    -DANDROID_NATIVE_API_LEVEL=26 \
    -DSANITIZER_ALLOW_CXXABI=OFF \
    -DLLVM_DEFAULT_TARGET_TRIPLE="${triplet%-*-*}-unknown-linux-android" \
    -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
    -DCMAKE_C_COMPILER_WORKS=1 \
    -DCMAKE_CXX_COMPILER_WORKS=1 \
    -DCMAKE_ASM_COMPILER_WORKS=1 \
    -DLLVM_ENABLE_RUNTIMES=libunwind \
    -DLIBUNWIND_ENABLE_SHARED=OFF
ninja -v install
popd

popd

# Build WASI SDK
pushd "$wasi"
cmake -G Ninja -B build/sysroot -S . \
    -DCMAKE_C_COMPILER="$llvm/build/stage1/clang/bin/clang" \
    -DCMAKE_CXX_COMPILER="$llvm/build/stage1/clang/bin/clang++" \
    -DCMAKE_INSTALL_PREFIX="$wasi/build/sysroot/install" \
    -DWASI_SDK_TARGETS=wasm32-wasip1 \
    -DWASI_SDK_LTO=OFF \
    -DWASI_SDK_EXCEPTIONS=OFF \
    -DWASI_SDK_BUILD_SHARED=OFF \
    -DWASI_SDK_CPU_CFLAGS=
cmake --build build/sysroot --target compiler-rt
cmake --build build/sysroot --target install
ln -s "$wasi/build/sysroot/install/wasi-resource-dir/lib/wasm32-unknown-wasip1" "$llvm/build/stage1/clang/lib/clang/22/lib/"
test -f "$llvm/build/stage1/clang/lib/clang/22/lib/wasm32-unknown-wasip1/libclang_rt.builtins.a"
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
# Viaduct from A-S requires concept-fetch 150.0.3 built with compileSdk 36.1.
# Build such a copy of concept-fetch from the current A-C source code
echo 150.0.3 > ../version.txt
sed -i -e '/compileSdkMajorVersion/s/37/36/' \
       -e '/compileSdkMinorVersion/s/2/1/' .config.yml
gradle :components:concept-fetch:publishToMavenLocal
git checkout .config.yml ../version.txt
# Required by UnifiedPush
gradle :components:{concept-base,concept-fetch,support-base,ui-icons}:publishToMavenLocal
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
