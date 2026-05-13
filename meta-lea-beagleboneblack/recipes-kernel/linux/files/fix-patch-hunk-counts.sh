#!/bin/sh
# fix-patch-hunk-counts.sh
#
# Recalculates and fixes all new-file hunk headers (@@ -0,0 +1,N @@) in a
# unified diff patch file.  Run this after editing any patch that adds a new
# file; it counts the actual '+' lines in each hunk and rewrites the header
# if the count is wrong.
#
# Usage:
#   ./fix-patch-hunk-counts.sh <patch-file>
#   ./fix-patch-hunk-counts.sh   # defaults to 0001-boneblack-maya-w271-sdio-uart1.patch

set -e

PATCH="${1:-$(dirname "$0")/0001-boneblack-maya-w271-sdio-uart1.patch}"

if [ ! -f "$PATCH" ]; then
    echo "ERROR: patch file not found: $PATCH" >&2
    exit 1
fi

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

changed=0
in_new_file_hunk=0
hunk_start_line=0
actual_count=0
line_num=0

# We need to both detect the hunk header for a new file and count the '+' lines
# that follow it.  awk handles this in a single pass and rewrites to tmpfile.
awk '
/^@@ -0,0 \+1,[0-9]+ @@/ {
    # Save the header line number and the claimed count
    claimed = 0
    match($0, /\+1,([0-9]+)/, arr)
    claimed = arr[1]
    in_hunk = 1
    actual = 0
    header_line = $0
    header_lineno = NR
    next
}
in_hunk && /^\+/ {
    actual++
    print
    next
}
in_hunk {
    # End of hunk (blank line, another @@ , or EOF handled in END)
    if (actual != claimed) {
        # Rewrite the saved header with the correct count
        gsub(/\+1,[0-9]+/, "+1," actual, header_line)
        printf "%s\n", header_line > "/dev/stderr"
        printf "FIXED: hunk header updated to +1,%d (was +1,%d)\n", actual, claimed > "/dev/stderr"
    }
    # Print the (possibly corrected) header before the current line
    # We buffered the header; print it now
    print header_line
    in_hunk = 0
    print
    next
}
{ print }
END {
    if (in_hunk) {
        if (actual != claimed) {
            gsub(/\+1,[0-9]+/, "+1," actual, header_line)
            printf "FIXED: hunk header updated to +1,%d (was +1,%d)\n", actual, claimed > "/dev/stderr"
        }
        print header_line
    }
}
' "$PATCH" > "$tmpfile" 2>&1

# Separate stderr (our FIXED messages) from the rewritten patch
awk '
/^@@ -0,0 \+1,[0-9]+ @@/ {
    claimed = 0
    match($0, /\+1,([0-9]+)/, arr)
    claimed = arr[1]
    in_hunk = 1
    actual = 0
    header = $0
    next
}
in_hunk && /^\+/ {
    actual++
    buf = buf $0 "\n"
    next
}
in_hunk {
    if (actual != claimed) {
        gsub(/\+1,[0-9]+/, "+1," actual, header)
        printf "FIXED: hunk updated from +1,%d to +1,%d\n", claimed, actual
    }
    printf "%s\n", header
    printf "%s", buf
    buf = ""
    in_hunk = 0
    print
    next
}
{ print }
END {
    if (in_hunk) {
        if (actual != claimed) {
            gsub(/\+1,[0-9]+/, "+1," actual, header)
            printf "FIXED: hunk updated from +1,%d to +1,%d\n", claimed, actual
        }
        printf "%s\n", header
        printf "%s", buf
    }
}
' "$PATCH" > "$tmpfile"

if diff -q "$PATCH" "$tmpfile" > /dev/null 2>&1; then
    echo "OK: $PATCH — all new-file hunk counts are correct"
else
    cp "$tmpfile" "$PATCH"
    echo "FIXED: $PATCH — hunk counts updated"
fi
