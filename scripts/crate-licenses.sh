#!/bin/sh
# Usage: crate-licenses.sh <workspace> <package> <target> <binary> <destination> <extra>
#
# Copies the license files of every crates.io crate that <package> depends on
# to <destination>/<crate>-<version>/. The crates are those that
# `cargo tree` lists for <target> with normal and build dependencies, read
# from the workspace's Cargo.lock with --locked. cargo checks each crate it
# downloads against the checksum in Cargo.lock; nothing is compiled and no
# build script runs. The files copied are those at the top of the crate whose
# names start with LICENSE, LICENCE, COPYING, COPYRIGHT, NOTICE or UNLICENSE,
# in any case.
#
# <extra>/<crate>-<version>/ holds license files that a crate does not ship;
# they are copied next to its own. A crate that ends up without a license
# file stops the script, and so does a directory in <extra> that matches no
# crate, so that the files are looked at again when the dependency changes.
#
# <binary> is the release binary built from the workspace. Its panic messages
# contain the source paths of the crates it was compiled from, and every crate
# named there must be in the list. Otherwise the binary was built from a
# different Cargo.lock. The paths start with
# .cargo/registry/src/<index>/<crate>-<version>/, or with
# <crate>-<version>/src/ when Cargo trims them. The standard library's own
# crates, under /rust/deps/, are left to rust-licenses.sh.
#
# Prints "<crate> <version>" for each crate.
set -eu

ws=$1
pkg=$2
target=$3
bin=$4
dest=$5
extra=$6

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
CARGO_HOME="$work/cargo"
export CARGO_HOME

cargo tree --locked --manifest-path "$ws/Cargo.toml" --package "$pkg" \
  --target "$target" --edges normal,build --prefix none --format '{p}' > "$work/tree"

# Lines are "<crate> v<version>", followed by the source for anything that is
# not on crates.io and by "(proc-macro)" or "(*)" markers. Path dependencies
# must be members of the workspace; their license is the workspace's own.
: > "$work/crates"
while read -r name ver src _; do
  case $name in
    "" | "["*) continue ;;
  esac
  case $ver in
    v[0-9]*) ;;
    *)
      echo "unexpected line from cargo tree: $name $ver $src" >&2
      exit 1
      ;;
  esac
  case $src in
    "" | "(proc-macro)" | "(*)") ;;
    "($ws/"*) continue ;;
    *)
      echo "$name $ver comes from $src, not from crates.io" >&2
      exit 1
      ;;
  esac
  echo "$name ${ver#v}" >> "$work/crates"
done < "$work/tree"
LC_ALL=C sort -u "$work/crates" > "$work/list"
test -s "$work/list" || { echo "cargo tree lists no crates for $pkg" >&2; exit 1; }

: > "$work/used"
while read -r name ver; do
  set -- "$CARGO_HOME"/registry/src/*/"$name-$ver"
  if [ "$#" -ne 1 ] || [ ! -f "$1/Cargo.toml" ]; then
    echo "$name $ver is not in $CARGO_HOME/registry/src" >&2
    exit 1
  fi
  src=$1
  out="$dest/$name-$ver"
  mkdir -p "$out"
  for f in "$src"/*; do
    case ${f##*/} in
      [Ll][Ii][Cc][Ee][Nn][CcSs][Ee]* | [Cc][Oo][Pp][Yy][Ii][Nn][Gg]* | \
      [Cc][Oo][Pp][Yy][Rr][Ii][Gg][Hh][Tt]* | [Nn][Oo][Tt][Ii][Cc][Ee]* | \
      [Uu][Nn][Ll][Ii][Cc][Ee][Nn][Ss][Ee]*)
        if [ -f "$f" ]; then cp "$f" "$out/"; fi
        ;;
    esac
  done
  if [ -d "$extra/$name-$ver" ]; then
    cp -R "$extra/$name-$ver/." "$out/"
    echo "$name-$ver" >> "$work/used"
  fi
  found=
  for f in "$out"/*; do
    if [ -f "$f" ]; then found=1; fi
  done
  if [ -z "$found" ]; then
    echo "$name $ver has no license file; add it to $extra/$name-$ver/" >&2
    exit 1
  fi
  echo "$name $ver"
done < "$work/list"

for dir in "$extra"/*; do
  if [ ! -d "$dir" ]; then continue; fi
  if ! grep -Fqx "${dir##*/}" "$work/used"; then
    echo "$dir: $pkg does not depend on this crate version" >&2
    exit 1
  fi
done

LC_ALL=C tr -c 'A-Za-z0-9_.+/-' '\n' < "$bin" > "$work/strings"
grep -oE '\.cargo/registry/src/[^/]+/[^/]+/' "$work/strings" \
  | sed 's,^.*/\([^/]*\)/$,\1,' \
  | LC_ALL=C sort -u > "$work/full"
grep -F /src/ "$work/strings" \
  | sed -e 's,\.cargo/registry/src/[^/]*/[^/]*/,/,g' -e 's,/rust/deps/[^/]*/,/,g' \
  | grep -oE '[A-Za-z0-9_-]+-[0-9]+\.[0-9]+\.[0-9]+[A-Za-z0-9.+-]*/src/' \
  | sed 's,/src/$,,' \
  | LC_ALL=C sort -u > "$work/trimmed"
if [ ! -s "$work/full" ] && [ ! -s "$work/trimmed" ]; then
  echo "$bin names no crate sources" >&2
  exit 1
fi
# Strings in the binary are not separated, so a trimmed path can follow other
# text. It counts as listed when it ends with a listed crate.
sed 's/ /-/' "$work/list" > "$work/names"
awk 'FILENAME == ARGV[1] { listed[$0] = 1; next }
  FILENAME == ARGV[2] { if (!($0 in listed)) print; next }
  { for (i = 1; i <= length($0); i++) if (substr($0, i) in listed) next; print }' \
  "$work/names" "$work/full" "$work/trimmed" > "$work/unlisted"
if [ -s "$work/unlisted" ]; then
  echo "$bin was built with crates that $pkg does not depend on in this Cargo.lock:" >&2
  cat "$work/unlisted" >&2
  exit 1
fi

find "$dest" -type d -exec chmod 0755 {} \;
find "$dest" -type f -exec chmod 0644 {} \;
