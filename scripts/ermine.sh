#!/bin/bash

DIRECTORY="$1"

METADATA="./-fdroiddata/metadata/com.deeperwire.ermine.yml"

echo "Changing repo location"
sed -i '/Repo:/s|: .*|: "https://github.com/Taknok/Ermine.git"|' $METADATA
sed -i '/AuthorName:/s|: .*|: "Deeper Wire"|' $METADATA
sed -i '/AuthorWebSite:/s|: .*|: "https://deeper-wire.com/"|' $METADATA
sed -i '/SourceCode:/s|: .*|: "https://github.com/Taknok/Ermine"|' $METADATA
sed -i '/IssueTracker:/s|: .*|: "https://github.com/Taknok/Ermine"|' $METADATA

echo "Changing commit id to tag"
# get all commit and versionName
python3 -c 'import yaml, re, sys; data = yaml.safe_load(open("./-fdroiddata/metadata/com.deeperwire.ermine.yml")); print("\n".join({f"{i["commit"]} {i["versionName"]}" for i in data["Builds"] if re.fullmatch(r"[0-9a-f]{40}", i["commit"])}))' > tmp.txt
while read -r SHA1 VERSION; do
    # Check if a tag exists for this commit
    TAG_EXISTS=$(git tag --points-at "$SHA1")
    NEW_TAG="v$VERSION"

    # If no tag exists, create one
    if [ -z "$TAG_EXISTS" ]; then
        echo "Creating tag $NEW_TAG for commit $SHA1"
        git tag "$NEW_TAG" "$SHA1"
    fi
    # Replace the SHA-1 commit with the new tag in the YAML file
    sed -i "s/$SHA1/$NEW_TAG/g" $METADATA
done < tmp.txt
rm tmp.txt

echo "Adding '-ermine' tag"
sed -i '/^\s*commit: /s/$/-ermine/' $METADATA

echo "Install xmlstarlet for manifest edit"
python3 -c 'import re, sys;
text = sys.stdin.read();
print(
  re.sub(
    r"(sudo:\n)([\w\W]*?)(\n^\s{4}\S)",
    r"\1\2\n      - apt-get install -y xmlstarlet\3",
    text,
  flags=re.MULTILINE)
)' < $METADATA > ./tmp.yml
mv tmp.yml $METADATA

echo "Replacing file content"
find "$DIRECTORY" -type f \
  -not -path "*/scripts/*" \
  -not -path "*/.git*/*" \
  -not -name "paths.sh" \
  -exec sed -i '/MozFennec/!s/Fennec/Ermine/g' {} +
find "$DIRECTORY" -type f \
  -not -path "*/scripts/*" \
  -not -path "*/.git*/*" \
  -exec sed -i 's/fennec_fdroid/ermine/g' {} +
find "$DIRECTORY" -type f \
  -not -path "*/scripts/*" \
  -not -path "*/.git*/*" \
  -exec sed -i 's/fennec/ermine/g' {} +

find "$DIRECTORY" -type f \
  -not -path "*/scripts/*" \
  -not -path "*/.git*/*" \
  -not -path "*.patch" \
  -exec sed -i 's/org\.mozilla/com\.deeperwire/g' {} +

find "$DIRECTORY" -type f \
  -not -path "*/scripts/*" \
  -not -path "*/.git*/*" \
  -exec sed -i 's/fennec_dos/ermine/g' {} +

# echo "Replacing file name"
# find "$DIRECTORY" -depth \
#   -not -path "*/.git*/*" \
#   -name "*fennec_dos*" \
#   -execdir bash -c 'mv "$1" "${1//fennec_dos/ermine}"' _ {} \;
# find "$DIRECTORY" -depth \
#   -not -path "*/.git*/*" \
#   -name "*us.spotco*" \
#   -execdir bash -c 'mv "$1" "${1//us.spotco/com.deeperwire}"' _ {} \;

echo "Replacing build id"
sed -i '/# Set up the app ID, version name and version code/,/# Disable crash reporting/c\
# Set up the app ID, version name and version code\
sed -i \\\
    -e '\''s|applicationId \"org.mozilla\"|applicationId \"com.deeperwire\"|'\'' \\\
    -e '\''s|applicationIdSuffix \".firefox\"|applicationIdSuffix \".ermine\"|'\'' \\\
    -e '\''s|\"sharedUserId\": \"org.mozilla.firefox.sharedID\"|\"sharedUserId\": \"com.deeperwire.ermine.sharedID\"|'\'' \\\
    -e \"s/Config.releaseVersionName(project)/'\''$1'\''/\" \\\
    -e \"s/Config.generateFennecVersionCode(arch, aab)/$2/\" \\\
    app/build.gradle\
sed -i \\\
    -e '\''/android:targetPackage/s/org.mozilla.firefox/com.deeperwire.ermine/'\'' \\\
    app/src/release/res/xml/shortcuts.xml\
\
# Disable crash reporting' ./prebuild.sh

echo "Adding compilation options"
sed -i '/cat << EOF > mozconfig/a \
ac_add_options --disable-profiling\
ac_add_options --disable-rust-debug\
ac_add_options --enable-hardening\
ac_add_options --enable-optimize\
ac_add_options --enable-rust-simd\
ac_add_options --enable-strip' ./prebuild.sh

echo "Removing wallpaper"
sed -i '/# Add wallpaper URL/d; /\.wallpaper_url/d' ./prebuild.sh

cat << 'EOT' >> ./prebuild.sh

pushd "$mozilla_release"

# Disable default browser notification
perl -i -0pe 's/(defaultBrowserNotificationDisplayed by booleanPreference[\s\S]*?default = )false/$1true/g' mobile/android/fenix/app/src/main/java/org/mozilla/fenix/utils/Settings.kt

# Change deeplink scheme
sed -i \
  -e 's|def deepLinkSchemeValue = "fenix|def deepLinkSchemeValue = "ermine|' \
  mobile/android/fenix/app/build.gradle

# Hide application
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
EOT

sed -i 's/\bgradle assembleRelease\b/gradle assembleRelease bundleRelease/' ./build.sh

pushd $DIRECTORY
  ./scripts/gen_res.sh
popd
