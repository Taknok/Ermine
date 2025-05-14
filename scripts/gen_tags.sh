#!/bin/bash

# Change commit id to tag
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
    sed -i "s/$SHA1/$NEW_TAG/g" ./-fdroiddata/metadata/com.deeperwire.ermine.yml
done < tmp.txt
rm tmp.txt
