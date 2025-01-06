#!/bin/bash

drawable="./fenix-overlay/res/drawable"


gen_webp() {
    INPUT_XML="$1"
    OUTPUT_WEBP="$2"
    SIZE="$3"

    # Temporary files
    TEMP_PNG="tmp.png"
    TEMP_RESIZED_PNG="tmp_resized.png"

    # Convert XML to PNG using Inkscape
    if command -v inkscape >/dev/null; then
        inkscape -z -e "$TEMP_PNG" "$INPUT_XML"
    else
        echo "Error: Inkscape is not installed."
        exit 1
    fi

    # Resize PNG if needed
    if command -v convert >/dev/null; then
        convert "$TEMP_PNG" -resize "$SIZE" "$TEMP_RESIZED_PNG"
    else
        echo "Error: ImageMagick is not installed."
        exit 1
    fi

    # Convert PNG to WebP
    if command -v cwebp >/dev/null; then
        cwebp "$TEMP_RESIZED_PNG" -o "$OUTPUT_WEBP"
        echo "WebP image created: $OUTPUT_WEBP"
    else
        echo "Error: cwebp is not installed."
        exit 1
    fi

    # Cleanup temporary files
    rm "$TEMP_PNG" "$TEMP_RESIZED_PNG"
}

gen_text() {
    font="Fira-Sans-Bold"
    wordmark="Ermine"

    SIZE="$1"
    FOLDER="$2"
    NAME="$3"

    # Generate the PNG
    convert -background transparent -fill white -font $font -gravity center -size "$SIZE" label:$wordmark $drawable-$FOLDER/$NAME.png

    # Convert the PNG to WebP
    cwebp $drawable-$FOLDER/$NAME.png -o $drawable-$FOLDER/$NAME.webp

    # Optional: Clean up the PNG if you don't need it
    rm $drawable-$FOLDER/$NAME.png
}

gen_wordmark() {
    SIZE="$1"
    FOLDER="$2"
    for name in "ic_logo_wordmark_normal ic_logo_wordmark_private ic_wordmark_text_normal ic_wordmark_text_private"; do
        gen_text "$SIZE" "$FOLDER" "$name"
    done
}

gen_wordmark "x80" "mdpi"
gen_webp "ic_lancher_foreground.xml" "$drawable-mdpi/ic_wordmark_logo.webp" "80x80"

gen_wordmark "x120" "hdpi"
gen_webp "ic_lancher_foreground.xml" "$drawable-hdpi/ic_wordmark_logo.webp" "120x120"

gen_wordmark "x160" "xhdpi"
gen_webp "ic_lancher_foreground.xml" "$drawable-xhdpi/ic_wordmark_logo.webp" "160x160"

gen_wordmark "x240" "xxhdpi"
gen_webp "ic_lancher_foreground.xml" "$drawable-xxhdpi/ic_wordmark_logo.webp" "240x240"

gen_wordmark "x320" "xxxhdpi"
gen_webp "ic_lancher_foreground.xml" "$drawable-xxxhdpi/ic_wordmark_logo.webp" "320x320"

