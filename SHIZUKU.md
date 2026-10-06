# StrykerOSS-Shizuku

This repository contains a reproducible Shizuku integration overlay for StrykerOSS 6.5.

The GitHub Actions workflow checks out upstream 6.5, applies the overlay, and builds debug and release APKs.

Stryker already contains a rootless QEMU/UML engine. The overlay replaces Android-side su process creation with Shizuku's privileged process API.

Shizuku through Sui/root gives UID 0. Shizuku through ADB/wireless debugging gives UID 2000 (shell). Host operations that fundamentally require Linux root capabilities, such as unrestricted mount/chroot or unrestricted /dev access, cannot become equivalent to root simply by changing the IPC transport. Those paths must use Stryker's rootless guest or a root-backed Shizuku provider.

The overlay uses Shizuku API 12.2.0 because newProcess() was public there; current Shizuku API releases are preparing to remove that transitional API in favor of UserService.
