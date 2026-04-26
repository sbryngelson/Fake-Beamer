# Contributing

Fake Beamer is mostly binary PowerPoint content, so useful pull requests need a little more context than a normal text diff.

## Editing workflow

1. Install the fonts from `computer-modern-fonts/`.
2. Edit the template, theme, or example deck in desktop PowerPoint.
3. Save the changed Office artifacts back to their existing paths:
   - `fake-beamer.thmx`
   - `fake-beamer.potx`
   - `example.pptx`
4. Update `images/title.png` or `images/content.png` if the visible design changed.
5. Run the package inspection script:

```sh
scripts/inspect-office-files.sh
```

The script checks that the OOXML zip packages are readable and prints a Markdown summary of slide layouts, slide text, theme colors, and referenced fonts.
See `docs/office-package-inspection.md` for more detail on what it reports.

## Pull request notes

Please include:

- What changed visually or behaviorally.
- Which PowerPoint version and operating system you tested with.
- Screenshots when layout, spacing, colors, or typography changed.
- Any changes to required fonts.

Try to keep unrelated Office-generated changes out of a pull request. PowerPoint may rewrite XML and thumbnails even when the visible change is small, so focused changes are much easier to review.

## Fonts

The bundled Computer Modern Unicode font source, version, and license notes are recorded in `docs/bundled-fonts.md`. Keep the license files in `computer-modern-fonts/` with any font updates, and run `scripts/inspect-office-files.sh --check` after changing the font bundle.
