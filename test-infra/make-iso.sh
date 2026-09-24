#!/bin/bash
# Сборка загрузочного ISO для gnumach-тестов без grub-mkrescue.
# grub.cfg встраивается в memdisk внутри core.img (гарантированно находится GRUB'ом),
# CD ищется через search --file /boot/gnumach.
# Использование: make-iso.sh <testname>
set -eu
TESTNAME="$1"
BUILD=/home/z/my-project/build-gnumach
GRUBDIR=/home/z/.tools-root/usr/lib/grub/i386-pc
MKIMAGE=/home/z/.tools-root/usr/bin/grub-mkimage
XORRISO=/home/z/.tools-root/usr/bin/xorriso
export LD_LIBRARY_PATH=/home/z/.tools-root/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}

ISO="$BUILD/tests/test-$TESTNAME.iso"
ISODIR="$BUILD/tests/isofiles-$TESTNAME"
MEMDIR="$BUILD/tests/memdisk-$TESTNAME"

[ -f "$BUILD/gnumach" ] && [ -f "$BUILD/tests/module-$TESTNAME" ] || { echo "нет ядра/модуля"; exit 1; }

# 1. grub.cfg (для memdisk): ищем CD по файлу ядра
mkdir -p "$MEMDIR/boot/grub"
sed -e "s|BOOTMODULE|module-$TESTNAME|g" \
    -e "s/GNUMACHARGS/console=com0/g" \
    -e "s/TEST_START_MARKER/booting-start-of-test/g" \
    /home/z/my-project/gnumach/tests/grub.cfg.single.template \
    | { echo 'set root=cd'; cat; } \
    > "$MEMDIR/boot/grub/grub.cfg"

# memdisk = tar с grub.cfg
tar -C "$MEMDIR" -cf "$BUILD/tests/memdisk-$TESTNAME.tar" boot

# embedded config: вывести GRUB на serial + VGA (для -nographic)
cat > "$BUILD/tests/embed-$TESTNAME.cfg" << 'EOF'
serial --unit=0 --speed=115200
terminal_input serial console
terminal_output serial console
EOF

# 2. core.img: модули для загрузки с CD (BIOS), multiboot1 для gnumach
"$MKIMAGE" -O i386-pc -d "$GRUBDIR" \
    -o "$BUILD/tests/core-$TESTNAME.img" \
    -m "$BUILD/tests/memdisk-$TESTNAME.tar" \
    -c "$BUILD/tests/embed-$TESTNAME.cfg" \
    -p '(memdisk)/boot/grub' \
    iso9660 biosdisk multiboot halt reboot echo test gzio search_fs_file search_label memdisk tar serial

# 3. El Torito boot image = cdboot.img + core.img
cat "$GRUBDIR/cdboot.img" "$BUILD/tests/core-$TESTNAME.img" > "$BUILD/tests/eltorito-$TESTNAME.img"

# 4. Дерево ISO: ядро + модуль + boot image
rm -rf "$ISODIR"
mkdir -p "$ISODIR/boot/grub"
cp "$BUILD/tests/eltorito-$TESTNAME.img" "$ISODIR/boot/grub/eltorito.img"
cp "$BUILD/gnumach" "$BUILD/tests/module-$TESTNAME" "$ISODIR/boot/"

# 5. ISO через xorriso (как grub-mkrescue: El Torito, no-emul-boot)
"$XORRISO" -as mkisofs \
    -o "$ISO" \
    -b "boot/grub/eltorito.img" -no-emul-boot -boot-load-size 4 -boot-info-table \
    -V GNUMACH_TEST \
    "$ISODIR" > /dev/null 2>&1

rm -rf "$ISODIR" "$MEMDIR" "$BUILD/tests/core-$TESTNAME.img" "$BUILD/tests/eltorito-$TESTNAME.img" "$BUILD/tests/memdisk-$TESTNAME.tar"
echo "OK: $ISO"
