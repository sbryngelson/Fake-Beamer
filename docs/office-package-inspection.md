# Office Package Inspection

PowerPoint files are OOXML zip packages. The repository includes a small inspection script to make binary changes easier to review:

```sh
scripts/inspect-office-files.sh
```

The script validates the zip structure and reports:

- package entry count
- slide layout names
- example slide text
- theme color values
- referenced typefaces

You can inspect a single file too:

```sh
scripts/inspect-office-files.sh fake-beamer.potx
```

CI also runs the invariant check mode:

```sh
scripts/inspect-office-files.sh --check
```

That mode fails if the expected template layouts, BeamerBlue theme color, CMU Sans Serif references, example slide count, bundled font count, or bundled CM Unicode 0.7.0 metadata drift unexpectedly.

This does not render slides or prove that PowerPoint will display everything correctly. For visual changes, still open the files in PowerPoint and update the README screenshots when needed.
