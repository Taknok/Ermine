#!/bin/bash

DIRECTORY="$1"

# Change repo location
sed -i '/Repo:/s|: .*|: "https://github.com/Taknok/Ermine.git"|' ./-fdroiddata/metadata/us.spotco.fennec_dos.yml

# Change for DW
sed -i '/AuthorName:/s|: .*|: "Deeper Wire"|' ./-fdroiddata/metadata/us.spotco.fennec_dos.yml
sed -i '/AuthorWebSite:/s|: .*|: "https://deeper-wire.com/"|' ./-fdroiddata/metadata/us.spotco.fennec_dos.yml
sed -i '/SourceCode:/s|: .*|: "https://github.com/Taknok/Ermine"|' ./-fdroiddata/metadata/us.spotco.fennec_dos.yml
sed -i '/IssueTracker:/s|: .*|: "https://github.com/Taknok/Ermine"|' ./-fdroiddata/metadata/us.spotco.fennec_dos.yml

# Change tag
sed -i '/^\s*commit: /s/$/-ermine/' ./-fdroiddata/metadata/us.spotco.fennec_dos.yml

# Install xmlstarlet for manifest edit
python3 -c 'import re, sys;
text = sys.stdin.read();
print(
  re.sub(
    r"(sudo:\n)([\w\W]*?)(\n^\s{4}\S)",
    r"\1\2\n      - apt-get install -y xmlstarlet\3",
    text,
  flags=re.MULTILINE)
)' < ./-fdroiddata/metadata/us.spotco.fennec_dos.yml > ./tmp.yml
mv tmp.yml ./-fdroiddata/metadata/us.spotco.fennec_dos.yml

echo "Mull"
echo "Replacing file content"
find "$DIRECTORY" -type f \
  -not -path "*/scripts/*" \
  -not -path "*/.git*/*" \
  -exec sed -i 's/Mull/Ermine/g' {} +
find "$DIRECTORY" -type f \
  -not -path "*/scripts/*" \
  -not -path "*/.git*/*" \
  -exec sed -i 's/mull/ermine/g' {} +

find "$DIRECTORY" -type f \
  -not -path "*/scripts/*" \
  -not -path "*/.git*/*" \
  -exec sed -i 's/us\.spotco/com\.deeperwire/g' {} +

echo "Replacing file name"
find "$DIRECTORY" -depth \
  -not -path "*/.git*/*" \
  -name "*mull*" \
  -execdir bash -c 'mv "$1" "${1//mull/ermine}"' _ {} \;
find "$DIRECTORY" -depth \
  -not -path "*/.git*/*" \
  -name "*us.spotco*" \
  -execdir bash -c 'mv "$1" "${1//us.spotco/com.deeperwire}"' _ {} \;

echo "Fennec"
echo "Replacing file content"
find "$DIRECTORY" -type f \
  -not -path "*/scripts/*" \
  -not -path "*/.git*/*" \
  -exec sed -i 's/fennec_dos/ermine/g' {} +

echo "Replacing file name"
find "$DIRECTORY" -depth \
  -not -path "*/.git*/*" \
  -name "*fennec_dos*" \
  -execdir bash -c 'mv "$1" "${1//fennec_dos/ermine}"' _ {} \;

cat << 'EOT' >> ./prebuild.sh

pushd "$mozilla_release"
sed -i \
  -e 's|def deepLinkSchemeValue = "fenix|def deepLinkSchemeValue = "ermine|' \
  mobile/android/fenix/app/build.gradle

xmlstarlet ed --inplace \
  -d '//uses-permission[@android:name="com.android.launcher.permission.INSTALL_SHORTCUT"]' \
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
  mobile/android/fenix/app/src/main/AndroidManifest.xml
popd
EOT

pushd $DIRECTORY
./gen_wordmark.sh
popd
