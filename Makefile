MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

.PHONY: default
.PHONY: images css files legacy
.PHONY: clean

# Fields
BUILD_SOURCES := \
	$(wildcard build/**/*) \
	cssnano.config.js

CSS_SOURCES   := $(wildcard src/css/*.css)
CSS_OUTPUTS   := \
	dist/css/min/black-highlighter.min.css \
	dist/css/min/normalize.min.css

IMAGE_SOURCES := $(wildcard src/img/*)
IMAGE_OUTPUTS := $(patsubst src/img/%,dist/img/%,$(IMAGE_SOURCES))

FILES_SOURCES := \
	src/misc/domicile.html \
	src/root/index.html \
	src/root/error.html
FILES_OUTPUTS := \
	dist/spherical/domicile.html \
	dist/index.html \
	dist/error.html

# Dynamic patching and building for any INT directories present
INT_BRANCHES  := $(patsubst src/css/int/%,%,$(wildcard src/css/int/*))

define INT_BRANCHES_template =
INT_SOURCES_$(1) := $(wildcard src/css/int/$(1)/*.patch)
INT_OUTPUTS_$(1) := \
	dist/css/int/$(1)/black-highlighter.css \
	dist/css/int/$(1)/normalize.css \
	dist/css/int/$(1)/min/black-highlighter.min.css \
	dist/css/int/$(1)/min/normalize.min.css

dist/css/int/$(1)/black-highlighter.css dist/css/int/$(1)/normalize.css: $(INT_SOURCES_$(1))
	build/int-patch-and-merge.sh $(1)

dist/css/int/$(1)/min/black-highlighter.min.css: dist/css/int/$(1)/black-highlighter.css
	npm run postcss -- --config build/css-minify -o $$@ $$<

dist/css/int/$(1)/min/normalize.min.css: dist/css/int/$(1)/normalize.css
	npm run postcss -- --config build/css-minify -o $$@ $$<
endef

LEGACY_CSS_SOURCES :=
LEGACY_CSS_OUTPUTS := \
	dist/stable/styles/black-highlighter.min.css \
	dist/stable/styles/normalize.min.css

# Top-level rules
default: images css files legacy

css: dist/css/min/ $(CSS_OUTPUTS) $(foreach lang,$(INT_BRANCHES),$(INT_OUTPUTS_$(lang)))
images: dist/img/ $(IMAGE_OUTPUTS)
files: $(FILES_OUTPUTS)
legacy: dist/stable/styles/ $(LEGACY_CSS_OUTPUTS)

# Directory creation
dist/%/:
	mkdir -p $@

# npm rules
node_modules:
	npm install

# CSS rules
dist/css/black-highlighter.css: src/css/black-highlighter.css $(BUILD_SOURCES) $(CSS_SOURCES) node_modules
	npm run postcss -- --config build/css-merge -o $@ $<
	cat \
		src/css/black-highlighter-wrap-begin.css \
		$@ \
		src/css/black-highlighter-wrap-close.css \
			> $@_
	mv $@_ $@

dist/css/min/black-highlighter.min.css: dist/css/black-highlighter.css node_modules
	npm run postcss -- --config build/css-minify -o $@ $<

dist/css/normalize.css: src/css/normalize.css $(BUILD_SOURCES) src/css/normalize-wrap-begin.css src/css/normalize-wrap-close.css
	cat \
		src/css/normalize-wrap-begin.css \
		$< \
		src/css/normalize-wrap-close.css \
			> $@

dist/css/min/normalize.min.css: dist/css/normalize.css node_modules
	npm run postcss -- --config build/css-minify -o $@ $<

# INT branch CSS rule
$(foreach lang,$(INT_BRANCHES),$(eval $(call INT_BRANCHES_template,$(lang))))

# Legacy symlinks for stable/styles CSS
dist/stable/styles/black-highlighter.min.css:
	cd $(@D); ln -s ../../css/min/$(@F)

dist/stable/styles/normalize.min.css:
	cd $(@D); ln -s ../../css/min/$(@F)

# Image optimization
dist/img/%.gif: src/img/%.gif node_modules
	npm run optimize -- gif $< $@

dist/img/%.png: src/img/%.png node_modules
	npm run optimize -- png $< $@

dist/img/%.svg: src/img/%.svg node_modules
	npm run optimize -- svg $< $@

# Static files
dist/spherical/domicile.html: src/misc/domicile.html
	install -D -m644 $< $@

dist/%.html: src/root/%.html
	install -D -m644 $< $@

# Utility rules
clean:
	rm -rf dist
