# Sourced by scripts/test-examples.sh before it starts this example: the
# board's sysfs and /proc, faked in files.
sys=$out/device-sys
rm -rf "$sys"
mkdir -p "$sys/zone" "$sys/led"
printf '47250\n' >"$sys/zone/temp"
printf '0\n' >"$sys/led/brightness"
printf '3725.41 7012.88\n' >"$sys/uptime"
export THERMAL="$sys/zone" LED="$sys/led" UPTIME="$sys/uptime"
