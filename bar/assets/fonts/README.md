# Isla Media Symbols

16 glyph subset of Google's Material Symbols Rounded, bundled so the player
uses the same filled rounded icons without a system font installation.
Source project: https://github.com/google/material-design-icons (Apache-2.0;
see LICENSE-MaterialSymbols.txt). No Swiftify code or assets are included.

Derived from the installed Material Symbols Rounded variable font. FontTools
instantiates FILL=1, wght=450, GRAD=0, opsz=24; subsets the Unicode codepoints
listed in MediaSymbol.qml and removes shaping features (private codepoints are
used directly). Family renamed to Isla Media Symbols to avoid system collisions.
The resulting file is about4KB. FontTools is only a preparation tool; no new
runtime dependency is required. Font name/copyright metadata is retained except
for the renamed family identifiers.
