# Test infrastructure (without distro root access)

Helper scripts to build gnumach and run its QEMU test-suite in an
environment without root, where `grub-mkrescue`/`make check` are not
directly usable (e.g. a sandbox).  Developed for x86_64 (the 64-bit
kernel requires GRUB's multiboot1 ELF64 relocator; plain `qemu -kernel`
cannot load it).

## What the scripts do

* `make-iso.sh <testname>` — builds `tests/test-<testname>.iso` without
  `grub-mkrescue`:
  - `grub-mkimage` builds `core.img` with the modules needed for CD boot
    (`iso9660 biosdisk multiboot halt reboot echo test gzio ...`);
  - `grub.cfg` (generated from `tests/grub.cfg.single.template`) is
    embedded into a memdisk inside `core.img`, so no prefix games on the
    CD are needed; the CD is selected with `set root=cd`;
  - El Torito boot image = `cdboot.img + core.img` (this is what
    `grub-mkrescue` does for BIOS-only images);
  - `xorriso -as mkisofs -b ... -no-emul-boot -boot-load-size 4
    -boot-info-table` produces the ISO.
* `run-test.sh <testname>` — runs QEMU exactly like
  `tests/run-qemu.sh.template` (`-m 2047 -nographic -no-reboot -boot d
  -cdrom ...`), checks the start/success/failure markers and returns the
  same exit codes (0 pass, 10 timeout, 12 missing reboot marker,
  99 explicit failure).

## Usage

    make gnumach MIG=/path/to/x86_64-gnu-mig
    make tests/module-hello ... tests/module-thread-state-fp \
         MIG=/path/to/x86_64-gnu-mig
    ./test-infra/run-test.sh hello     # or any test name from tests/

## Sandbox toolchain notes

For reference, the environment used had these user-space unpacked
tools: autoconf 2.69 + automake 1.16 (needed for the
`config.status.dep.patch` bootstrap hack), Debian's
`mig-x86-64-gnu` (>= 1.8+git20231217 — older mig lacks
`type X = struct {...}` support used by current defs files),
qemu-system-x86, grub-pc-bin, grub-common, xorriso.
