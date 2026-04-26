# Bundled Fonts

This repository bundles the Computer Modern Unicode font set for convenience.

- Font project: Computer Modern Unicode fonts, also identified as CM Unicode.
- Bundled version: 0.7.0.
- Release date: June 18, 2009.
- Local files: 33 TrueType fonts in `computer-modern-fonts/`.
- Upstream homepage recorded by the bundled font README: http://canopus.iacp.dvo.ru/~panov/cm-unicode/
- Copyright holder recorded by the bundled OFL file: Andrey V. Panov, 2003-2009.
- Reserved font family name: Computer Modern Unicode fonts.
- Font license: SIL Open Font License, Version 1.1.

The version is recorded in two local places:

- `computer-modern-fonts/FontLog.txt` starts with `CM Unicode 0.7.0 (June 18 2009)`.
- Each bundled `.ttf` contains the metadata string `Version 0.7.0`.

The bundled README describes the fonts as conversions from METAFONT sources using `mftrace`, `autotrace`, and FontForge, with some glyphs copied from Blue Sky Type 1 fonts released by AMS. It records these source references:

- `http://lilypond.org/mftrace/`
- `http://fontforge.sf.net/`
- `http://canopus.iacp.dvo.ru/~panov/cm-unicode/`
- `ftp://cam.ctan.org/tex-archive/fonts/ec/`
- `ftp://cam.ctan.org/tex-archive/fonts/cyrillic/lh`
- `ftp://cam.ctan.org/tex-archive/fonts/greek/cb`
- `ftp://cam.ctan.org/tex-archive/fonts/tipa`
- `ftp://cam.ctan.org/tex-archive/language/vietnamese/vntex/unpacked/fonts/source/vntex/vnr/`

Run this check before changing the font bundle:

```sh
scripts/inspect-office-files.sh --check
```
