# Sourced by scripts/test-examples.sh before it starts this program: an
# empty directory for the attachments.
attachments=$out/attachments
rm -rf "$attachments"
mkdir -p "$attachments"
export ATTACHMENTS="$attachments"
