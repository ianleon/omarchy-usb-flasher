#!/bin/bash
# omarchy-usb-flasher write helper. Runs as root under pkexec.
#
#   flash.sh <iso> <device> <verify:0|1>
#
# Everything it prints on stdout is a protocol line for the UI:
#
#   PID <pid>          the root pid to signal when the user cancels
#   TOTAL <bytes>      size of the payload, for the progress bar
#   STAGE <name>       unmount | wipe | write | sync | hash-iso | hash-device
#   <n> bytes ...      raw dd progress, carriage returns already unfolded
#   VERIFY_OK          hashes matched
#   VERIFY_FAIL        hashes differed
#   ERROR <message>    fatal, shown verbatim to the user
#   DONE               finished cleanly
set -u
set -o pipefail

iso=${1:?usage: flash.sh <iso> <device> <verify>}
dev=${2:?usage: flash.sh <iso> <device> <verify>}
verify=${3:-0}

say() { printf '%s\n' "$*"; }
die() { say "ERROR $*"; exit 1; }

child=""
cancelled=0
on_term() {
  cancelled=1
  [[ -n $child ]] && kill -TERM "$child" 2>/dev/null
}
trap on_term TERM INT

say "PID $$"

[[ -r $iso ]] || die "Cannot read $iso"
[[ -e $dev ]] || die "$dev is gone — was the drive unplugged?"

size=$(stat -Lc %s "$iso") || die "Cannot stat $iso"
(( size > 0 )) || die "$iso is empty"
say "TOTAL $size"

# A regular-file target is allowed so the pipeline can be exercised without a
# real drive; everything disk-specific below is skipped for it.
if [[ -b $dev ]]; then
  devsize=$(blockdev --getsize64 "$dev") || die "Cannot read the size of $dev"
  (( devsize >= size )) || die "$dev holds $devsize bytes, the ISO needs $size"

  say "STAGE unmount"
  while read -r part; do
    [[ -n $part ]] || continue
    umount "$part" 2>/dev/null
    swapoff "$part" 2>/dev/null
  done < <(lsblk -nrpo NAME "$dev" | tac)

  say "STAGE wipe"
  wipefs -a "$dev" >/dev/null 2>&1
fi

say "STAGE write"
ddflags=(bs=4M conv=fsync)
[[ -b $dev ]] && ddflags+=(oflag=direct)
dd if="$iso" of="$dev" "${ddflags[@]}" status=progress 2>&1 | tr '\r' '\n' &
child=$!
wait "$child"
rc=$?
child=""
(( cancelled )) && { say "ERROR Cancelled — $dev is now half-written and not bootable"; exit 4; }
(( rc == 0 )) || die "Write failed (dd exited $rc)"

say "STAGE sync"
sync
[[ -b $dev ]] && blockdev --flushbufs "$dev" 2>/dev/null

if [[ $verify == 1 ]]; then
  # stderr carries dd's progress; fd 3 is the real stdout, so the hash on
  # stdout stays clean for the command substitution to capture.
  exec 3>&1
  say "STAGE hash-iso"
  isohash=$(dd if="$iso" bs=4M status=progress 2> >(tr '\r' '\n' >&3) | sha256sum | cut -d' ' -f1)
  say "STAGE hash-device"
  devhash=$(dd if="$dev" bs=4M count="$size" iflag=count_bytes status=progress 2> >(tr '\r' '\n' >&3) | sha256sum | cut -d' ' -f1)
  if [[ $isohash == "$devhash" ]]; then
    say "VERIFY_OK"
  else
    say "VERIFY_FAIL"
    die "Verification failed: the drive does not match the ISO"
  fi
fi

say "DONE"
