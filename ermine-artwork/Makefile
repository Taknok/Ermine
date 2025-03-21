#
#    Fennec build scripts
#    Copyright (C) 2020-2024  Matías Zúñiga, Andrew Nayenko
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

resdir := ../fenix-overlay/res
flidir := ../fastlane/metadata/android/en-US/images
images := $(foreach x,hdpi mdpi xhdpi xxhdpi xxxhdpi, \
                    $(resdir)/mipmap-$(x)/ic_launcher.webp \
                    $(resdir)/mipmap-$(x)/ic_launcher_foreground.webp \
                    $(resdir)/drawable-$(x)/ic_logo_wordmark_normal.webp \
                    $(resdir)/drawable-$(x)/ic_logo_wordmark_private.webp) \
          $(resdir)/drawable/ic_wordmark_text_normal.webp \
          $(resdir)/drawable/ic_wordmark_text_private.webp \
          $(resdir)/drawable/ic_wordmark_logo.webp \
          $(flidir)/icon.png

all: $(images)

clean:
	rm -f $(images)

define rasterize
mkdir -p $(dir $@)
$(eval temp := $(shell mktemp).png)
inkscape $< -o $(temp) --export-area=$(1) -h $(2)
$(if $(filter .webp,$(suffix $@)),
     cwebp -quiet $(temp) -o $@,
     optipng -o7 -clobber -quiet -out $@ $(temp))
rm $(temp)
endef

# Legacy non-adaptive icon

$(resdir)/mipmap-mdpi/ic_launcher.webp : ic_launcher_foreground.svg
	$(call rasterize,0:0:512:512,48)

$(resdir)/mipmap-hdpi/ic_launcher.webp : ic_launcher_foreground.svg
	$(call rasterize,0:0:512:512,72)

$(resdir)/mipmap-xhdpi/ic_launcher.webp : ic_launcher_foreground.svg
	$(call rasterize,0:0:512:512,96)

$(resdir)/mipmap-xxhdpi/ic_launcher.webp : ic_launcher_foreground.svg
	$(call rasterize,0:0:512:512,144)

$(resdir)/mipmap-xxxhdpi/ic_launcher.webp : ic_launcher_foreground.svg
	$(call rasterize,0:0:512:512,192)

# Adaptive icon foreground

$(resdir)/mipmap-mdpi/ic_launcher_foreground.webp : ic_launcher_foreground.svg
	$(call rasterize,0:0:512:512,108)

$(resdir)/mipmap-hdpi/ic_launcher_foreground.webp : ic_launcher_foreground.svg
	$(call rasterize,0:0:512:512,162)

$(resdir)/mipmap-xhdpi/ic_launcher_foreground.webp : ic_launcher_foreground.svg
	$(call rasterize,0:0:512:512,216)

$(resdir)/mipmap-xxhdpi/ic_launcher_foreground.webp : ic_launcher_foreground.svg
	$(call rasterize,0:0:512:512,324)

$(resdir)/mipmap-xxxhdpi/ic_launcher_foreground.webp : ic_launcher_foreground.svg
	$(call rasterize,0:0:512:512,432)

# Wordmark normal

$(resdir)/drawable-mdpi/ic_logo_wordmark_normal.webp : ic_logo_wordmark_normal.svg
	$(call rasterize,0:0:188:32,80)

$(resdir)/drawable-hdpi/ic_logo_wordmark_normal.webp : ic_logo_wordmark_normal.svg
	$(call rasterize,0:0:188:32,120)

$(resdir)/drawable-xhdpi/ic_logo_wordmark_normal.webp : ic_logo_wordmark_normal.svg
	$(call rasterize,0:0:188:32,160)

$(resdir)/drawable-xxhdpi/ic_logo_wordmark_normal.webp : ic_logo_wordmark_normal.svg
	$(call rasterize,0:0:188:32,240)

$(resdir)/drawable-xxxhdpi/ic_logo_wordmark_normal.webp : ic_logo_wordmark_normal.svg
	$(call rasterize,0:0:188:32,320)

# Wordmark private

$(resdir)/drawable-mdpi/ic_logo_wordmark_private.webp : ic_logo_wordmark_private.svg
	$(call rasterize,0:0:188:32,80)

$(resdir)/drawable-hdpi/ic_logo_wordmark_private.webp : ic_logo_wordmark_private.svg
	$(call rasterize,0:0:188:32,120)

$(resdir)/drawable-xhdpi/ic_logo_wordmark_private.webp : ic_logo_wordmark_private.svg
	$(call rasterize,0:0:188:32,160)

$(resdir)/drawable-xxhdpi/ic_logo_wordmark_private.webp : ic_logo_wordmark_private.svg
	$(call rasterize,0:0:188:32,240)

$(resdir)/drawable-xxxhdpi/ic_logo_wordmark_private.webp : ic_logo_wordmark_private.svg
	$(call rasterize,0:0:188:32,320)

# Wordmark normal, text-only

$(resdir)/drawable/ic_wordmark_text_normal.webp : ic_logo_wordmark_normal.svg
	$(call rasterize,80:0:188:32,70)

# Wordmark private, text-only

$(resdir)/drawable/ic_wordmark_text_private.webp : ic_logo_wordmark_private.svg
	$(call rasterize,80:0:188:32,70)

# Wordmark logo

$(resdir)/drawable/ic_wordmark_logo.webp : ic_internal.svg
	$(call rasterize,0:0:64:64,160)

# Notification logo
$(resdir)/drawable/ic_status_logo.xml : ic_launcher_monochrome.xml
	cp $< $@

# Fastlane metadata icon

$(flidir)/icon.png : ic_internal.svg
	$(call rasterize,0:0:64:64,512)

.PNONY: all clean
