#!/usr/bin/env bash
set -euo pipefail

DEFAULT_FILES=(
  "fake-beamer.thmx"
  "fake-beamer.potx"
  "example.pptx"
)

CHECK_MODE=0
FILES=()

usage() {
  cat <<'USAGE'
Usage:
  scripts/inspect-office-files.sh [--check] [file ...]

Without arguments, print a Markdown summary for the repository's Office files.
With --check, validate expected repository invariants for Office files and fonts.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)
      CHECK_MODE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      FILES+=("$1")
      ;;
  esac
  shift
done

CUSTOM_FILE_COUNT=${#FILES[@]}

if [ "${#FILES[@]}" -eq 0 ]; then
  FILES=("${DEFAULT_FILES[@]}")
fi

if [ "$CHECK_MODE" -eq 1 ] && [ "$CUSTOM_FILE_COUNT" -gt 0 ]; then
  echo "--check validates the default repository files and does not accept a custom file list." >&2
  exit 1
fi

for cmd in find perl sort strings tr unzip wc; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
done

if [ "$CHECK_MODE" -eq 1 ]; then
  FILES=("${DEFAULT_FILES[@]}")
fi

archive_entries() {
  unzip -Z1 "$1"
}

has_archive_entry() {
  local archive="$1"
  local expected_entry="$2"
  local entry

  while IFS= read -r entry; do
    if [ "$entry" = "$expected_entry" ]; then
      return 0
    fi
  done < <(archive_entries "$archive")

  return 1
}

number_sort() {
  perl -e 'print sort { (($a =~ /(\d+)/)[0] || 0) <=> (($b =~ /(\d+)/)[0] || 0) || $a cmp $b } <>'
}

join_lines() {
  perl -e 'chomp(my @lines = <STDIN>); print join("|", @lines);'
}

xml_text_summary() {
  perl -0777 -ne '
    my @text;
    while (/<a:t>(.*?)<\/a:t>/sg) {
      my $t = $1;
      $t =~ s/&amp;/&/g;
      $t =~ s/&lt;/</g;
      $t =~ s/&gt;/>/g;
      $t =~ s/&quot;/"/g;
      $t =~ s/&apos;/'"'"'/g;
      $t =~ s/\s+/ /g;
      push @text, $t if length $t;
    }
    my $summary = join " ", @text;
    $summary =~ s/^\s+|\s+$//g;
    print substr($summary, 0, 160);
    print "..." if length($summary) > 160;
  '
}

layout_name() {
  unzip -p "$1" "$2" | perl -0777 -ne '
    if (/<p:cSld[^>]*\bname="([^"]+)"/s) {
      print $1;
    } else {
      print "(unnamed)";
    }
  '
}

slide_layout_entries() {
  archive_entries "$1" |
    perl -ne 'print if m{^(ppt|theme)/slideLayouts/slideLayout[0-9]+\.xml$}' |
    number_sort
}

slide_entries() {
  archive_entries "$1" |
    perl -ne 'print if m{^ppt/slides/slide[0-9]+\.xml$}' |
    number_sort
}

theme_entries() {
  archive_entries "$1" |
    perl -ne 'print if m{^(ppt/theme|theme/theme)/theme[0-9]*\.xml$}' |
    number_sort
}

layout_names() {
  local archive="$1"
  local entry

  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    layout_name "$archive" "$entry"
    echo
  done < <(slide_layout_entries "$archive")
}

theme_scheme() {
  unzip -p "$1" "$2" | perl -0777 -ne '
    if (/<a:clrScheme[^>]*\bname="([^"]+)"/s) {
      print $1;
    }
  '
}

theme_color() {
  local archive="$1"
  local entry="$2"
  local key="$3"

  unzip -p "$archive" "$entry" | KEY="$key" perl -0777 -ne '
    my $key = $ENV{"KEY"};
    if (/<a:\Q$key\E\b[^>]*>.*?<a:srgbClr[^>]*\bval="([0-9A-Fa-f]{6})"/s) {
      print uc($1);
    }
  '
}

typefaces() {
  local archive="$1"
  local xml_entries

  xml_entries=$(
    archive_entries "$archive" |
      perl -ne 'print if m{^(ppt|theme)/(slideMasters|slideLayouts|theme)/.*\.xml$}' |
      sort
  )

  if [ -z "$xml_entries" ]; then
    return
  fi

  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    unzip -p "$archive" "$entry"
  done <<< "$xml_entries" |
    perl -ne 'while (/typeface="([^"]+)"/g) { print "$1\n" }' |
    sort -u
}

print_theme_colors() {
  local archive="$1"
  local entries

  entries=$(theme_entries "$archive")

  if [ -z "$entries" ]; then
    echo "- Theme colors: none found"
    return
  fi

  echo "- Theme colors:"
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    unzip -p "$archive" "$entry" | ENTRY="$entry" perl -0777 -ne '
      my $entry = $ENV{"ENTRY"};
      my $xml = $_;
      my ($scheme) = $xml =~ /<a:clrScheme[^>]*\bname="([^"]+)"/s;
      $scheme ||= "(unnamed)";
      print "  - `$entry`: `$scheme`\n";
      for my $key (qw(dk1 lt1 dk2 lt2 accent1 accent2 accent3 accent4 accent5 accent6 hlink folHlink)) {
        if ($xml =~ /<a:\Q$key\E\b[^>]*>.*?<a:srgbClr[^>]*\bval="([0-9A-Fa-f]{6})"/s) {
          print "    - `$key`: `#" . uc($1) . "`\n";
        }
      }
    '
  done <<< "$entries"
}

print_slide_layouts() {
  local archive="$1"
  local layouts

  layouts=$(slide_layout_entries "$archive")

  if [ -z "$layouts" ]; then
    echo "- Slide layouts: none found"
    return
  fi

  echo "- Slide layouts:"
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    echo "  - \`$entry\`: \`$(layout_name "$archive" "$entry")\`"
  done <<< "$layouts"
}

print_slides() {
  local archive="$1"
  local slides

  slides=$(slide_entries "$archive")

  if [ -z "$slides" ]; then
    return
  fi

  echo "- Slides:"
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    local summary
    summary=$(unzip -p "$archive" "$entry" | xml_text_summary)
    if [ -z "$summary" ]; then
      summary="(no text)"
    fi
    echo "  - \`$entry\`: $summary"
  done <<< "$slides"
}

print_typefaces() {
  local archive="$1"
  local fonts
  fonts=$(typefaces "$archive")

  if [ -z "$fonts" ]; then
    echo "- Referenced typefaces: none found"
    return
  fi

  echo "- Referenced typefaces:"
  while IFS= read -r typeface; do
    [ -n "$typeface" ] || continue
    echo "  - \`$typeface\`"
  done <<< "$fonts"
}

FAILURES=0

check_passed() {
  echo "OK: $1"
}

check_failed() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

assert_equal() {
  local actual="$1"
  local expected="$2"
  local label="$3"

  if [ "$actual" = "$expected" ]; then
    check_passed "$label"
  else
    check_failed "$label (expected '$expected', got '$actual')"
  fi
}

contains_line() {
  local lines="$1"
  local expected="$2"
  local line

  while IFS= read -r line; do
    if [ "$line" = "$expected" ]; then
      return 0
    fi
  done <<< "$lines"

  return 1
}

assert_contains_line() {
  local lines="$1"
  local expected="$2"
  local label="$3"

  if contains_line "$lines" "$expected"; then
    check_passed "$label"
  else
    check_failed "$label (missing '$expected')"
  fi
}

assert_file_contains() {
  local file="$1"
  local expected="$2"
  local label="$3"

  if [ ! -f "$file" ]; then
    check_failed "$label (missing file '$file')"
    return
  fi

  if PATTERN="$expected" perl -0ne 'exit(index($_, $ENV{"PATTERN"}) >= 0 ? 0 : 1)' "$file"; then
    check_passed "$label"
  else
    check_failed "$label (missing '$expected')"
  fi
}

check_file_and_zip() {
  local archive="$1"

  if [ -f "$archive" ]; then
    check_passed "$archive exists"
  else
    check_failed "$archive exists"
    return
  fi

  if unzip -tq "$archive" >/dev/null; then
    check_passed "$archive zip integrity"
  else
    check_failed "$archive zip integrity"
  fi
}

check_exact_layouts() {
  local archive="$1"
  local expected="$2"
  local actual

  actual=$(layout_names "$archive" | join_lines)
  assert_equal "$actual" "$expected" "$archive has expected slide layouts"
}

check_layout_prefix() {
  local archive="$1"
  local expected="$2"
  local actual

  actual=$(layout_names "$archive" | perl -ne 'print if $. <= 6' | join_lines)
  assert_equal "$actual" "$expected" "$archive starts with expected slide layouts"
}

check_slide_count() {
  local archive="$1"
  local expected="$2"
  local actual

  actual=$(slide_entries "$archive" | wc -l | tr -d '[:space:]')
  assert_equal "$actual" "$expected" "$archive has expected slide count"
}

check_theme_invariants() {
  local archive="$1"
  local entry="$2"
  local expected_scheme="$3"
  local expected_accent1="$4"
  local actual_scheme
  local actual_accent1

  if ! has_archive_entry "$archive" "$entry"; then
    check_failed "$archive contains $entry"
    return
  fi

  check_passed "$archive contains $entry"
  actual_scheme=$(theme_scheme "$archive" "$entry")
  actual_accent1=$(theme_color "$archive" "$entry" "accent1")
  assert_equal "$actual_scheme" "$expected_scheme" "$archive theme scheme name"
  assert_equal "$actual_accent1" "$expected_accent1" "$archive accent1 color"
}

check_typeface_invariants() {
  local archive="$1"
  local archive_typefaces

  archive_typefaces=$(typefaces "$archive")
  assert_contains_line "$archive_typefaces" "CMU Sans Serif" "$archive references CMU Sans Serif"
  assert_contains_line "$archive_typefaces" "CMU Sans Serif Medium" "$archive references CMU Sans Serif Medium"
}

check_font_bundle() {
  local font_dir="computer-modern-fonts"
  local expected_header="CM Unicode 0.7.0 (June 18 2009)"
  local font_files
  local font_count
  local bad_versions=""
  local font

  if [ -d "$font_dir" ]; then
    check_passed "$font_dir exists"
  else
    check_failed "$font_dir exists"
    return
  fi

  font_files=$(find "$font_dir" -maxdepth 1 -type f -name '*.ttf' | sort)
  font_count=$(printf '%s\n' "$font_files" | perl -ne 'print if /\S/' | wc -l | tr -d '[:space:]')
  assert_equal "$font_count" "33" "bundled CMU font count"

  if [ -f "$font_dir/FontLog.txt" ]; then
    local header
    header=$(perl -ne 'if (/\S/) { chomp; print; exit }' "$font_dir/FontLog.txt")
    assert_equal "$header" "$expected_header" "CM Unicode FontLog version"
  else
    check_failed "CM Unicode FontLog version (missing FontLog.txt)"
  fi

  while IFS= read -r font; do
    [ -n "$font" ] || continue
    if ! strings "$font" | perl -ne '$ok = 1 if /^Version 0\.7\.0\s*$/; END { exit($ok ? 0 : 1) }'; then
      bad_versions="${bad_versions}${bad_versions:+, }${font##*/}"
    fi
  done <<< "$font_files"

  if [ -z "$bad_versions" ]; then
    check_passed "all bundled TTFs report Version 0.7.0"
  else
    check_failed "all bundled TTFs report Version 0.7.0 (mismatch: $bad_versions)"
  fi

  assert_file_contains "$font_dir/README" "http://canopus.iacp.dvo.ru/~panov/cm-unicode/ (homepage)" "CM Unicode upstream homepage is recorded"
  assert_file_contains "$font_dir/OFL.txt" "Reserved Font Family Name \"Computer Modern Unicode fonts\"." "CM Unicode reserved font name is recorded"
  assert_file_contains "$font_dir/OFL.txt" "SIL Open Font License, Version 1.1" "CM Unicode license version is recorded"
}

run_checks() {
  local expected_template_layouts="Title Slide|Title and Content|Two Content|Comparison|Title Only|Blank"
  local archive

  echo "# Office Package Invariant Checks"
  echo

  for archive in "${DEFAULT_FILES[@]}"; do
    check_file_and_zip "$archive"
  done

  check_exact_layouts "fake-beamer.thmx" "$expected_template_layouts"
  check_exact_layouts "fake-beamer.potx" "$expected_template_layouts"
  check_layout_prefix "example.pptx" "$expected_template_layouts"
  check_slide_count "example.pptx" "5"

  check_theme_invariants "fake-beamer.thmx" "theme/theme/theme1.xml" "BeamerBlue" "3331B4"
  check_theme_invariants "fake-beamer.potx" "ppt/theme/theme1.xml" "BeamerBlue" "3331B4"
  check_theme_invariants "example.pptx" "ppt/theme/theme1.xml" "BeamerBlue" "3331B4"

  for archive in "${DEFAULT_FILES[@]}"; do
    check_typeface_invariants "$archive"
  done

  check_font_bundle

  echo
  if [ "$FAILURES" -eq 0 ]; then
    echo "All invariant checks passed."
  else
    echo "$FAILURES invariant check(s) failed." >&2
    exit 1
  fi
}

if [ "$CHECK_MODE" -eq 1 ]; then
  run_checks
  exit 0
fi

echo "# Office Package Summary"
echo
echo "Generated by \`scripts/inspect-office-files.sh\`."
echo

for archive in "${FILES[@]}"; do
  if [ ! -f "$archive" ]; then
    echo "Missing file: $archive" >&2
    exit 1
  fi

  if ! unzip -tq "$archive" >/dev/null; then
    echo "Invalid Office package: $archive" >&2
    exit 1
  fi

  entry_count=$(archive_entries "$archive" | wc -l | tr -d '[:space:]')

  echo "## $archive"
  echo
  echo "- Zip integrity: OK"
  echo "- Package entries: $entry_count"
  print_slide_layouts "$archive"
  print_slides "$archive"
  print_theme_colors "$archive"
  print_typefaces "$archive"
  echo
done
