#!/bin/bash
# Runner для gnumach-тестов: ISO (GRUB) + QEMU, логика tests/run-qemu.sh.template.
#   timeout 60s -> exit 10; failure marker -> exit 99; нет success marker -> exit 12
# Использование: run-test.sh <testname>
set -u
TESTNAME="$1"
BUILD=/home/z/my-project/build-gnumach
QEMU=/home/z/.tools/bin/qemu-system-x86_64
LOG="$BUILD/tests/test-$TESTNAME.raw"
START_MARKER="booting-start-of-test"
SUCCESS_MARKER="gnumach-test-success-and-reboot"
FAILURE_MARKER="gnumach-test-failure"

[ -f "$BUILD/tests/test-$TESTNAME.iso" ] || /home/z/my-project/scripts/make-iso.sh "$TESTNAME" || exit 1
rm -f "$LOG"

cd "$BUILD"
timeout -v --foreground --kill-after=3 60s \
    "$QEMU" -m 2047 -nographic -no-reboot -boot d \
    -cpu core2duo-v1 \
    -cdrom "tests/test-$TESTNAME.iso" 2>&1 | tee "$LOG" | sed -n "/$START_MARKER/,\$p"
rc=${PIPESTATUS[0]}

if [ $rc -ne 0 ]; then
    exit 10   # timeout / qemu error
fi
if grep -qi "$FAILURE_MARKER" "$LOG"; then
    exit 99   # тест явно провален
fi
if ! grep -q "$SUCCESS_MARKER" "$LOG"; then
    exit 12   # нет success-маркера (краш ядра?)
fi
exit 0
