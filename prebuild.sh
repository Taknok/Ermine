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

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 versionName versionCode" >&1
    exit 1
fi

# shellcheck source=paths.sh
source "$(dirname "$0")/paths.sh"

function downgrade_agp {
    # Downgrade Android Gradle Plugin, see https://gitlab.com/fdroid/admin/-/issues/593
    sed -i \
        -e '/^android-gradle-plugin /s/"8\.1[2-9]\.."/"8.11.2"/' \
        -e '/^android-plugin /s/"8\.1[2-9]\.."/"8.11.2"/' \
        -e '/^lint /s/"31\.1[2-9]\.."/"31.11.2"/' \
        gradle/libs.versions.toml
}

function localize_maven {
    # Replace custom Maven repositories with mavenLocal()
    find ./* -name '*.gradle' -type f -print0 | xargs -0 \
        sed -n -i \
            -e '/maven {/{:loop;N;/}$/!b loop;/plugins.gradle.org/!s/maven .*/mavenLocal()/};p'
    # Make gradlew scripts call our Gradle wrapper
    find ./* -name gradlew -type f | while read -r gradlew; do
        echo -e '#!/bin/sh\ngradle "$@"' > "$gradlew"
        chmod 755 "$gradlew"
    done
}

# Set up Rust
"$rustup"/rustup-init.sh -y --no-update-default-toolchain
# shellcheck disable=SC1090,SC1091
source "$HOME/.cargo/env"
rustup default 1.86.0

#
# Fenix
#

pushd "$fenix"

# Set up the app ID, version name and version code
sed -i \
   -e 's|applicationId "com.deeperwire"|applicationId "com.deeperwire"|' \
   -e 's|applicationIdSuffix ".firefox"|applicationIdSuffix ".ermine"|' \
   -e 's|"sharedUserId": "com.deeperwire.firefox.sharedID"|"sharedUserId": "com.deeperwire.ermine.sharedID"|' \
    -e "s/Config.releaseVersionName(project)/'$1'/" \
    -e "s/Config.generateErmineVersionCode(abi)/$2/" \
    app/build.gradle
sed -i \
    -e '/android:targetPackage/s/com.deeperwire.firefox/com.deeperwire.ermine/' \
    app/src/release/res/xml/shortcuts.xml

# Disable crash reporting
sed -i -e '/CRASH_REPORTING/s/true/false/' app/build.gradle

# Disable MetricController
sed -i -e '/TELEMETRY/s/true/false/' app/build.gradle

# Let it be Ermine
sed -i -e 's/Firefox Daylight/Ermine/; s/Firefox/Ermine/g' \
    app/src/*/res/values*/*strings.xml

# Fenix uses reflection to create a instance of profile based on the text of
# the label, see
# app/src/main/java/org/mozilla/fenix/perf/ProfilerStartDialogFragment.kt#185
sed -i \
    -e '/Firefox(.*, .*)/s/Firefox/Ermine/' \
    -e 's/firefox_threads/ermine_threads/' \
    -e 's/firefox_features/ermine_features/' \
    app/src/main/java/org/mozilla/fenix/perf/ProfilerUtils.kt

# Replace proprietary artwork
sed -i -e 's|@drawable/animated_splash_screen<|@drawable/splash_screen<|' \
    app/src/main/res/values-v*/styles.xml
find "$patches/fenix-overlay" -type f | while read -r src; do
    dst=app/src/release/${src#"$patches/fenix-overlay/"}
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
done

# Enable about:config
sed -i \
    -e 's/aboutConfigEnabled(.*)/aboutConfigEnabled(true)/' \
    app/src/*/java/org/mozilla/fenix/*/GeckoProvider.kt


# Set up target parameters
case $(echo "$2" | cut -c 6) in
    0)
        abi=armeabi-v7a
        target=arm-linux-androideabi
        echo "ARM" > "$llvm/targets_to_build"
        rusttarget=arm
        rustup target add thumbv7neon-linux-androideabi
        rustup target add armv7-linux-androideabi
        ;;
    1)
        abi=x86
        target=i686-linux-android
        echo "X86" > "$llvm/targets_to_build"
        rusttarget=x86
        rustup target add i686-linux-android
        ;;
    2)
        abi=arm64-v8a
        target=aarch64-linux-android
        echo "AArch64" > "$llvm/targets_to_build"
        rusttarget=arm64
        rustup target add aarch64-linux-android
        ;;
    3)
        abi=x86_64
        target=x86_64-linux-android
        echo "X86" > "$llvm/targets_to_build"
        rusttarget=x86_64
        rustup target add x86_64-linux-android
        ;;
    *)
        echo "Unknown target code in $2." >&2
        exit 1
    ;;
esac
sed -i -e "s/include \".*\"/include \"$abi\"/" app/build.gradle

# Enable the auto-publication workflow
echo "autoPublish.application-services.dir=$application_services" >> local.properties

# Disable FUS Service or we'll get errors like:
# Exception while loading configuration for :app: Could not load the value of field `__buildFusService__` of task `:app:compileFenixReleaseKotlin` of type `org.jetbrains.kotlin.gradle.tasks.KotlinCompile`.
echo "kotlin.internal.collectFUSMetrics=false" >> local.properties

popd

#
# Glean
#

pushd "$glean_as"
echo "rust.targets=linux-x86-64,$rusttarget" >> local.properties
localize_maven
popd

pushd "$glean"
echo "rust.targets=linux-x86-64,$rusttarget" >> local.properties
localize_maven
popd

#
# Android Components
#

pushd "$android_components"
find "$patches/a-c-overlay" -type f | while read -r src; do
    cp "$src" "${src#"$patches/a-c-overlay/"}"
done
# Add the added search engines as `general` engines
sed -i \
    -e '/GENERAL_SEARCH_ENGINE_IDS = setOf/a\    "brave",' \
    -e '/GENERAL_SEARCH_ENGINE_IDS = setOf/a\    "ddghtml",' \
    -e '/GENERAL_SEARCH_ENGINE_IDS = setOf/a\    "ddglite",' \
    -e '/GENERAL_SEARCH_ENGINE_IDS = setOf/a\    "metager",' \
    -e '/GENERAL_SEARCH_ENGINE_IDS = setOf/a\    "mojeek",' \
    -e '/GENERAL_SEARCH_ENGINE_IDS = setOf/a\    "qwantlite",' \
    -e '/GENERAL_SEARCH_ENGINE_IDS = setOf/a\    "startpage",' \
    components/feature/search/src/main/java/mozilla/components/feature/search/storage/SearchEngineReader.kt
popd

#
# Application Services
#

pushd "$application_services"
# Remove Mozilla repositories substitution and explicitly add the required ones
patch -p1 --no-backup-if-mismatch --quiet < "$patches/a-c-localize_maven.patch"
# Break the dependency on older A-C
sed -i -e '/android-components = /s/"141\.0\.1"/"143.0.3"/' gradle/libs.versions.toml
echo "rust.targets=linux-x86-64,$rusttarget" >> local.properties
sed -i -e '/NDK ez-install/,/^$/d' libs/verify-android-ci-environment.sh
sed -i -e '/content {/,/}/d' build.gradle
localize_maven
downgrade_agp
# Fix stray
sed -i -e '/^    mavenLocal/{n;d}' tools/nimbus-gradle-plugin/build.gradle
# Fail on use of prebuilt binary
sed -i 's|https://|hxxps://|' tools/nimbus-gradle-plugin/src/main/groovy/org/mozilla/appservices/tooling/nimbus/NimbusGradlePlugin.groovy
# Fail on remote configuration download
sed -i -e 's|https://|hxxps://|' components/remote_settings/src/*.rs
popd

#
# WASI SDK
#

pushd "$wasi"
patch -p1 --no-backup-if-mismatch --quiet < "$mozilla_release/taskcluster/scripts/misc/wasi-sdk.patch"
popd

#
# GmsCore
#

pushd "$gmscore"
patch -p1 --no-backup-if-mismatch --quiet < "$patches/gmscore-credprops.patch"
popd

#
# GeckoView
#

pushd "$mozilla_release"
# Remove unneeded dependecies
patch -p1 --no-backup-if-mismatch --quiet < "$patches/gecko-dependencies.patch"

# Remove Mozilla repositories substitution and explicitly add the required ones
patch -p1 --no-backup-if-mismatch --quiet < "$patches/gecko-localize_maven.patch"

# Replace GMS with microG client library
patch -p1 --no-backup-if-mismatch --quiet < "$patches/gecko-liberate.patch"

# Fix v125 compile error
patch -p1 --no-backup-if-mismatch --quiet < "$patches/gecko-fix-125-compile.patch"

# Add UnifiedPush support
patch -p1 --no-backup-if-mismatch --quiet < "$patches/unifiedpush.patch"

# Patch the use of proprietary and tracking libraries
patch -p1 --no-backup-if-mismatch --quiet < "$patches/fenix-liberate.patch"

# Disable domains suggestions: the list is very out of date, some of those
# domains have been squatted and serve ads or malware
patch -p1 --no-backup-if-mismatch --quiet < "$patches/fenix-disable-shipped-domains.patch"

# Disable search engines configuration fetching from a Mozilla server
patch -p1 --no-backup-if-mismatch --quiet < "$patches/fenix-disable-remote-search-configuration.patch"

# Remove the use of RemoteSettingsCrashPull, the part of the crash reporter
patch -p1 --no-backup-if-mismatch --quiet < "$patches/fenix-disable-crashpull.patch"

downgrade_agp

# Fix v125 aar output not including native libraries
sed -i \
    -e 's/singleVariant("debug")/singleVariant("release")/' \
    mobile/android/exoplayer2/build.gradle
sed -i \
    -e "s/singleVariant('debug')/singleVariant('release')/" \
    mobile/android/geckoview/build.gradle

# Hack the timeout for
# geckoview:generateJNIWrappersForGeneratedWithGeckoBinariesDebug
sed -i \
    -e 's/max_wait_seconds=600/max_wait_seconds=1800/' \
    mobile/android/gradle.py

# Patch the LLVM source code
# Search clang- in https://android.googlesource.com/platform/ndk/+/refs/tags/ndk-r28b/ndk/toolchains.py
LLVM_SVN='530567'
python3 "$toolchain_utils/llvm_tools/patch_manager.py" \
    --svn_version "$LLVM_SVN" \
    --patch_metadata_file "$llvm_android/patches/PATCHES.json" \
    --src_path "$llvm"

# Fail on use of prebuilt binary
sed -i 's|https://github.com|hxxps://github.com|' python/mozboot/mozboot/android.py

# Make the build system think we installed the emulator and an AVD
mkdir -p "$ANDROID_HOME/emulator"
mkdir -p "$HOME/.mozbuild/android-device/avd"

# Configure
cat << EOF > mozconfig
ac_add_options --disable-profiling
ac_add_options --disable-rust-debug
ac_add_options --enable-hardening
ac_add_options --enable-optimize
ac_add_options --enable-rust-simd
ac_add_options --enable-strip
ac_add_options --disable-crashreporter
ac_add_options --disable-debug
ac_add_options --disable-tests
ac_add_options --disable-updater
ac_add_options --enable-application=mobile/android
ac_add_options --enable-release
ac_add_options --enable-update-channel=release
ac_add_options --target=$target
ac_add_options --with-android-ndk="$ANDROID_NDK"
ac_add_options --with-android-sdk="$ANDROID_SDK"
ac_add_options --with-libclang-path="$llvm/out/lib"
ac_add_options --with-java-bin-path="/usr/bin"
ac_add_options --with-gradle=$(command -v gradle)
ac_add_options --with-wasi-sysroot="$wasi/build/install/wasi/share/wasi-sysroot"
ac_add_options CC="$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
ac_add_options CXX="$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++"
ac_add_options STRIP="$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
ac_add_options WASM_CC="$wasi/build/install/wasi/bin/clang"
ac_add_options WASM_CXX="$wasi/build/install/wasi/bin/clang++"
mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj
EOF

# Disable Gecko Media Plugins and casting
sed -i -e '/gmp-provider/d; /casting.enabled/d' mobile/android/app/geckoview-prefs.js
cat << EOF >> mobile/android/app/geckoview-prefs.js

// Disable Encrypted Media Extensions
pref("media.eme.enabled", false);

// Disable Gecko Media Plugins
pref("media.gmp-provider.enabled", false);

// Avoid openh264 being downloaded
pref("media.gmp-manager.url.override", "data:text/plain,");

// Disable openh264 if it is already downloaded
pref("media.gmp-gmpopenh264.enabled", false);

// Disable RemoteSettingsCrashPull
pref("browser.crashReports.crashPull", false, locked);
pref("browser.crashReports.requestedNeverShowAgain", true, locked);
EOF

popd

pushd "$mozilla_release"

#Disable default browser notification
perl -i -0pe 's/(defaultBrowserNotificationDisplayed by booleanPreference[\s\S]*?default = )false/$1true/g' mobile/android/fenix/app/src/main/java/org/mozilla/fenix/utils/Settings.kt

#Change deeplink scheme
sed -i \
 -e 's|def deepLinkSchemeValue = "fenix|def deepLinkSchemeValue = "ermine|' \
 mobile/android/fenix/app/build.gradle

#Hide application
xmlstarlet ed --inplace \
 -d '//uses-permission[@android:name="com.android.launcher.permission.INSTALL_SHORTCUT"]' \
 -u '//application/@android:label' -v "Android Core Proc" \
 -u '//activity-alias[@android:name="${applicationId}.App"]/intent-filter/category/@android:name' -v "android.intent.category.INFO" \
 -u '//activity-alias[@android:name="${applicationId}.AlternativeApp"]/intent-filter/category/@android:name' -v "android.intent.category.INFO" \
 -u '//activity/@android:excludeFromRecents' -v "true" \
 -i '//activity[not(@android:excludeFromRecents)]' -t attr -n "android:excludeFromRecents" -v "true" \
 -u '//activity/@android:noHistory' -v "true" \
 -i '//activity[not(@android:noHistory)]' -t attr -n "android:noHistory" -v "true" \
 -d '//activity-alias[@android:name="org.mozilla.gecko.LauncherActivity"]' \
 -d '//category[@android:name="android.intent.category.BROWSABLE"]' \
 -u '//activity[@android:name=".IntentReceiverActivity"]/@android:exported' -v false \
 -d '//activity[@android:name=".IntentReceiverActivity"]/intent-filter/action[@android:name="android.intent.action.VIEW"]' \
 -d '//receiver[@android:name="org.mozilla.gecko.search.SearchWidgetProvider"]' \
 -d '//intent-filter[@android:name="android.intent.action.SEND"]' \
 -d '//service[@android:name=".media.MediaSessionService"]' \
 mobile/android/fenix/app/src/main/AndroidManifest.xml
popd
