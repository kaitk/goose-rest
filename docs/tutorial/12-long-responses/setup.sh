# Sourced by scripts/test-examples.sh before it starts this program: project
# 1's files, a text file of 220 KB, 20,000 lines of 11 bytes.
files=$out/files
rm -rf "$files"
mkdir -p "$files/1" "$files/2"
awk 'BEGIN { for (i = 1; i <= 20000; i++) printf "line %05d\n", i }' >"$files/1/plans.txt"
export FILES="$files"
