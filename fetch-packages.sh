#!/bin/bash -e

CURDIR="$(readlink -f "$(dirname "$0")")"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT ERR

mkdir -pv "$TMPDIR/"{lists,sources}
DESTDIR="${1}"
shift 1

OPTIONS=(
    -o Dir::Etc::SourceParts="$TMPDIR/sources" -o Dir::Cache::archives="$DESTDIR"
    -o Dir::Cache::pkgcache="$TMPDIR/lists/pkgcache.bin" -o Dir::Cache::srcpkgcache="$TMPDIR/lists/srcpkgcache.bin"
    -o Dir::State::Lists="$TMPDIR/lists" -o 'APT::Architecture=loong64'
)

cp -v "$CURDIR"/*.sources "$TMPDIR/sources/"
apt-get update "${OPTIONS[@]}"

mkdir -pv "$DESTDIR"
pushd "$DESTDIR"
apt-get download "${OPTIONS[@]}" "$@"
popd

if command -v apt-ftparchive >/dev/null 2>&1; then
    apt-ftparchive packages "$DESTDIR" >"$DESTDIR/Packages"
    xz -T0 -9c "$DESTDIR/Packages" > "$DESTDIR/Packages.xz"
fi
