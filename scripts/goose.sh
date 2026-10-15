#!/bin/sh
# Sourced by the scripts that run the Goose compiler, after they set root: sets
# and exports GOOSE (docs/development.md, "Set up the Goose compiler"), the
# first of:
#
#   GOOSE          already set: the compiler as given, such as a checkout's build
#   GOOSE_COMMIT   that commit of aardappel/goose, which the first use clones and
#                  builds with CMake into build/goose-<commit>/
#   (neither)      the pinned release below, which the first use downloads into
#                  build/goose-<release>-<asset>/ and checks against its SHA-256;
#                  on a platform the release has no archive for, such as Linux
#                  on arm64, its tag built as GOOSE_COMMIT would be
#
# GOOSE_ASSET picks another platform's release, such as linux-x64 for Docker on
# macOS. goose_version prints which compiler GOOSE is, for env.txt.
#
# Run directly, it prints the compiler's path, downloading it if needed:
#   GOOSE=$(scripts/goose.sh)

goose_release=v2026.1

goose_fetch() {
    case ${GOOSE_ASSET:-$(uname -s)-$(uname -m)} in
    linux-x64 | Linux-x86_64)
        asset=linux-x64
        sum=c4b7eabfaef9662d451a8d760e44215cfd8a4ed10a4e32e2769820508aa79c9a ;;
    macos-arm64 | Darwin-arm64)
        asset=macos-arm64
        sum=939be9b05b983fc4a474ed13a7448d8638911829fabcfb2d0d58357bd39c88e5 ;;
    macos-x64 | Darwin-x86_64)
        asset=macos-x64
        sum=64dcae32d6e8ef511f44dc2d0799034bea034bfa4f27866550a5d35165bcb73e ;;
    windows-x64 | MINGW*-x86_64 | MSYS*-x86_64 | CYGWIN*-x86_64)
        asset=windows-x64
        sum=dcca0f1fa9b6681b77d27aaee3d4d892b1fe2fdf291248db5beeabcd62c63eb5 ;;
    *) return 2 ;;
    esac
    name=goose-$goose_release-$asset
    dir=$root/build/$name
    exe=$dir/goose
    [ "$asset" = windows-x64 ] && exe=$exe.exe
    if [ ! -x "$exe" ]; then
        case $asset in windows-x64) file=$name.zip ;; *) file=$name.tar.gz ;; esac
        echo "downloading Goose $goose_release ($asset) into $dir" >&2
        tmp=$root/build/.goose-download
        rm -rf "$tmp" && mkdir -p "$tmp" || return 1
        curl -fsSL -o "$tmp/$file" \
            "https://github.com/aardappel/goose/releases/download/$goose_release/$file" ||
            return 1
        if command -v sha256sum >/dev/null; then
            got=$(sha256sum "$tmp/$file")
        else
            got=$(shasum -a 256 "$tmp/$file")
        fi
        if [ "${got%% *}" != "$sum" ]; then
            echo "$file: SHA-256 ${got%% *}, expected $sum" >&2
            return 1
        fi
        case $file in
        *.zip)
            # Git Bash has no unzip by default; Windows' own tar reads zip.
            if command -v unzip >/dev/null; then
                unzip -q "$tmp/$file" -d "$tmp" || return 1
            else
                "$SYSTEMROOT/System32/tar.exe" -xf "$tmp/$file" -C "$tmp" || return 1
            fi ;;
        *) tar -xzf "$tmp/$file" -C "$tmp" || return 1 ;;
        esac
        [ "$asset" = "${asset#macos}" ] || xattr -dr com.apple.quarantine "$tmp/$name" 2>/dev/null || :
        rm -rf "$dir"
        mv "$tmp/$name" "$dir" || return 1
        rm -rf "$tmp"
    fi
    GOOSE=$exe
}

goose_build() {
    dir=$root/build/goose-$GOOSE_COMMIT
    if [ ! -f "$dir/CMakeLists.txt" ]; then
        echo "cloning Goose $GOOSE_COMMIT into $dir" >&2
        rm -rf "$dir"
        git init -q "$dir" &&
            git -C "$dir" fetch -q --depth 1 https://github.com/aardappel/goose.git "$GOOSE_COMMIT" &&
            git -C "$dir" checkout -q FETCH_HEAD || return 1
    fi
    for exe in "$dir/build/goose" "$dir/build/Release/goose.exe"; do
        [ -x "$exe" ] && { GOOSE=$exe; return; }
    done
    echo "building Goose $GOOSE_COMMIT" >&2
    if command -v ninja >/dev/null; then
        cmake -S "$dir" -B "$dir/build" -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
    else
        cmake -S "$dir" -B "$dir/build" -DCMAKE_BUILD_TYPE=Release >/dev/null
    fi || return 1
    cmake --build "$dir/build" --config Release -j >/dev/null || return 1
    for exe in "$dir/build/goose" "$dir/build/Release/goose.exe"; do
        [ -x "$exe" ] && { GOOSE=$exe; return; }
    done
    echo "the build of Goose $GOOSE_COMMIT left no compiler in $dir/build" >&2
    return 1
}

# A checkout's build names its commit, a release outside build/ its directory,
# and anything else its path.
goose_version() {
    if [ "${goose_from_release:-}" ]; then
        echo "$goose_release"
        return
    fi
    d=$(cd "$(dirname "$(command -v "$GOOSE" || echo "$GOOSE")")" && pwd)
    top=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || top=
    if [ -n "$top" ] && [ -d "$top/stdlib" ] && [ -d "$top/src" ]; then
        git -C "$top" rev-parse --short HEAD
    else
        case $(basename "$d") in goose-v*) basename "$d" ;; *) echo "$GOOSE" ;; esac
    fi
}

if [ -z "${GOOSE:-}" ]; then
    root=${root:-$(cd "$(dirname "$0")/.." && pwd)}
    if [ -n "${GOOSE_COMMIT:-}" ]; then
        goose_build || exit 1
    else
        goose_fetch || {
            [ $? = 2 ] || exit 1
            echo "no Goose $goose_release release for $(uname -s) $(uname -m);" \
                "building its source" >&2
            GOOSE_COMMIT=$goose_release goose_build || exit 1
        }
        goose_from_release=1
    fi
fi
export GOOSE

case $(basename "$0") in goose.sh) echo "$GOOSE" ;; esac
