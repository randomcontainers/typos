#!/bin/sh
# Usage: rust-licenses.sh <binary> <destination>
#
# Copies the license files of the Rust release that <binary> was built with,
# as named by the rustc version in its .comment section, to <destination>.
# The binary links that release's standard library, whose source is the
# release's rust-src archive. The archive is downloaded from
# static.rust-lang.org and checked against the SHA-256 in its .sha256 file.
# Every license file in it is copied: those of rust-lang/rust, those in the
# library tree, which include the crates.io crates that the standard library
# vendors under library/vendor/, and that of LLVM's libunwind, which Rust
# links into its musl targets. Paths below rust-src/lib/rustlib/src/rust/ in
# the archive are kept below <destination>.
#
# The panic messages in the binary contain the source paths of the standard
# library, with the commit of the release, and of the vendored crates. The
# commit must be the archive's, and every vendored crate named must be in the
# archive.
#
# Prints the URL and SHA-256 of the archive.
set -eu

bin=$1
dest=$2

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

readelf -p .comment "$bin" > "$work/comment"
sed -n 's/^.*rustc version \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\) (.*$/\1/p' "$work/comment" \
  | LC_ALL=C sort -u > "$work/rustc"
if [ "$(grep -c . "$work/rustc")" != 1 ]; then
  echo "$bin does not name one stable rustc release:" >&2
  cat "$work/comment" >&2
  exit 1
fi
ver=$(cat "$work/rustc")

archive="rust-src-$ver.tar.xz"
url="https://static.rust-lang.org/dist/$archive"
curl -fsSL --proto '=https' --tlsv1.2 --retry 3 -o "$work/$archive" "$url"
curl -fsSL --proto '=https' --tlsv1.2 --retry 3 -o "$work/$archive.sha256" "$url.sha256"
sha256=$(awk -v f="$archive" '$2 == f && $1 ~ /^[0-9a-f]+$/ && length($1) == 64 { print $1 }' "$work/$archive.sha256")
test -n "$sha256" || { echo "$archive.sha256 has no SHA-256 for $archive" >&2; exit 1; }
echo "$sha256  $work/$archive" | sha256sum -c - > /dev/null \
  || { echo "$archive does not match its .sha256 file" >&2; exit 1; }

xz -dc "$work/$archive" > "$work/rust-src.tar"
mkdir "$work/src"
tar -xf "$work/rust-src.tar" -C "$work/src"
top="$work/src/rust-src-$ver"
root="$top/rust-src/lib/rustlib/src/rust"
test -d "$root/library/vendor" || { echo "$archive has no library/vendor/" >&2; exit 1; }
case $(cat "$top/version") in
  "$ver "*) ;;
  *)
    echo "$archive is not Rust $ver: $(cat "$top/version")" >&2
    exit 1
    ;;
esac
commit=$(cat "$top/git-commit-hash")

LC_ALL=C tr -c 'A-Za-z0-9_.+/-' '\n' < "$bin" > "$work/strings"
grep -oE '/rustc/[0-9a-f]{40}/' "$work/strings" | LC_ALL=C sort -u > "$work/commits"
if [ "$(cat "$work/commits")" != "/rustc/$commit/" ]; then
  echo "$bin was not built with the standard library of Rust $ver ($commit); it names:" >&2
  cat "$work/commits" >&2
  exit 1
fi
grep -oE '/rust/deps/[^/]+/' "$work/strings" \
  | sed -e 's,^/rust/deps/,,' -e 's,/$,,' \
  | LC_ALL=C sort -u > "$work/deps"
while read -r dep; do
  if [ ! -d "$root/library/vendor/$dep" ]; then
    echo "$bin was built with $dep, which Rust $ver does not vendor" >&2
    exit 1
  fi
done < "$work/deps"

mkdir -p "$dest"
find "$top" -type f > "$work/files"
while IFS= read -r f; do
  case ${f##*/} in
    [Ll][Ii][Cc][Ee][Nn][CcSs][Ee]* | [Cc][Oo][Pp][Yy][Ii][Nn][Gg]* | \
    [Cc][Oo][Pp][Yy][Rr][Ii][Gg][Hh][Tt]* | [Nn][Oo][Tt][Ii][Cc][Ee]* | \
    [Uu][Nn][Ll][Ii][Cc][Ee][Nn][Ss][Ee]*) ;;
    *) continue ;;
  esac
  rel=${f#"$top"/}
  rel=${rel#rust-src/lib/rustlib/src/rust/}
  case $rel in
    */*) mkdir -p "$dest/${rel%/*}" ;;
  esac
  cp "$f" "$dest/$rel"
done < "$work/files"
for f in COPYRIGHT LICENSE-APACHE LICENSE-MIT src/llvm-project/libunwind/LICENSE.TXT; do
  test -s "$dest/$f" || { echo "$archive has no $f" >&2; exit 1; }
done

echo "rust-src: $url"
echo "rust-src-sha256: $sha256"
