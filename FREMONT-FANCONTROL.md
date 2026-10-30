# Fremont fan control

This document describes the optional Fremont fan-control support developed for
Steamify, its safety boundaries, and the validation completed before offering
the work for review.

## Motivation and scope

Valve's Fremont Steam Machine uses the `steamdeck` MFD driver to bind its
`VLV0100` ACPI device and `steamdeck_hwmon` to expose the fan through Linux's
hwmon interface. Some CachyOS standard and LTS kernels do not provide both
modules, while Deckify kernels may already provide them natively. Without the
complete provider pair, Steam's existing hardware-management stack cannot use
the fan interface.

Steamify adds an opt-in **Fan monitoring / control (DKMS)** child below
**Steam Machine support**. It supplies only missing safe module providers,
installs CachyOS's `jupiter-fan-control` package when needed, and prepares both
modules for the next boot.

The feature does not implement a fan curve, add another control daemon, or
change the normal SteamOS choice between OS and firmware fan control. Steam and
the existing `steamos-manager` integration remain responsible for that choice;
`jupiter-fan-control` implements the OS curve.

## Implementation

### Drivers and DKMS

Both modules are built as one DKMS package, `steamify-steamdeck/1`:

- `steamdeck` is the MFD/EC-facing parent driver that binds the Fremont ACPI
  device and creates its child devices.
- `steamdeck_hwmon` exposes the fan readings and target through hwmon.

The vendored files are original Valve GPL-2.0+ drivers. Their documented source
path is Valve's Linux integration work through the `evlaV/linux-integration`
mirror; Steamify carries the tested snapshot from
`firlin123/steamdeck-dkms` commit `99737c4`. Exact SHA-256 pins are checked
before staging the sources for DKMS. See [`patches/README.md`](patches/README.md)
for the source inventory and hashes in `lib/steamdeck-hwmon.sh`.

Installation does not download or clone kernel sources. The two reviewed files,
the Makefile, and the DKMS template are part of the Steamify checkout and are
copied from the local checkout or release bundle into `/usr/src`.

### Provider handling

Provider detection is performed per installed kernel and per module. Steamify
distinguishes native or built-in providers, its own DKMS package, complete
foreign provider pairs, missing providers, and unsafe partial or conflicting
states.

- Missing safe providers can be supplied by Steamify DKMS.
- Native providers are reused and never overwritten. This includes Deckify
  kernels that already contain both modules.
- A complete foreign pair is preserved.
- Partial, conflicting, or unverifiable providers fail closed before system
  changes are made.
- Standard, LTS, and Deckify kernels can coexist; Steamify builds only for the
  kernels that need its providers.

### Package, boot, and ownership lifecycle

`jupiter-fan-control` is installed only from a verified official `cachyos*`
repository. Steamify never enables or starts it directly. The package's vendor
unit and Steam's existing manager control its runtime state.

Kernel-module changes deliberately have a reboot boundary. Installation writes
an owned modules-load file in dependency order but does not load either module
live. Removal does not unbind the ACPI device or unload a running module. If
Jupiter is active, it is stopped normally first so its firmware handoff can
run; loaded modules remain until reboot.

Ownership state records whether Steamify owns DKMS, autoload, the Jupiter
package, or a protective service mask. Removal affects only verified
Steamify-owned resources. Pre-existing packages and native or foreign module
providers are retained. Missing, damaged, or contradictory ownership evidence
fails closed rather than adopting or deleting unknown artifacts. Interrupted
installations and removals are resumed by reconciling the recorded operation
with the real package, DKMS, provider, and file state.

More implementation detail is available in
[`TECHNICAL.md`](TECHNICAL.md#front-led-bar-steam-machine).

## Installation and use

On a detected Valve Fremont system, open the Steamify app, enable **Steam
Machine support**, then enable its optional **Fan monitoring / control (DKMS)**
child and review the plan before applying it. The same component is available
in the regular terminal menu. Enabling the child also keeps its parent selected;
enabling the parent alone does not opt in to fan control.

After a successful installation, restart when Steamify requests it. These are
separate states:

1. **Feature installed:** the required package, DKMS providers, autoload file,
   and ownership state are present.
2. **Modules active:** after the requested restart, the kernel has loaded
   `steamdeck` and `steamdeck_hwmon`, and `VLV0100:00` is bound.
3. **OS fan control active:** Steam's OS fan-control setting is enabled and
   `jupiter-fan-control.service` is active; hwmon has a nonzero target.
4. **Firmware fan control active:** Steam's OS setting is disabled, Jupiter is
   inactive, and the target is zero; the firmware controls the fan.

Useful read-only checks after the restart include:

```bash
dkms status | grep steamify-steamdeck
readlink /sys/bus/acpi/devices/VLV0100:00/driver
ls /sys/class/hwmon/hwmon*/fan1_{input,target,fault}
systemctl status jupiter-fan-control.service
```

The hwmon directory number is assigned dynamically. Read `name` in the same
directory to identify `steamdeck_hwmon`, then inspect `fan1_input` and
`fan1_target` there.

To remove the support, untick **Fan monitoring / control (DKMS)** in the app or
terminal menu and apply the reviewed plan while leaving **Steam Machine
support** selected if its other functions should remain. Steamify hands active
OS control back to firmware, removes only resources it owns, and requests a
restart when loaded modules must disappear from the running kernel.

Manual `modprobe`, module unbinding, or ad-hoc DKMS removal is not part of the
normal installation or removal procedure.

## Limitations

The drivers originated for Steam Deck hardware. Some Deck-oriented attributes
are not meaningful on Fremont and may report implausible values. In particular,
`fan1_fault=1` was observed on the tested Fremont machine and is not a reliable
indicator of a physical fan fault there. The useful `fan1_input` and
`fan1_target` values, OS curve, and firmware handoff worked correctly.

Installation or removal may look complete in Steamify before the running
kernel reflects the new module state. A restart is required whenever Steamify
shows the restart marker.

## Validation

Detailed individual runs are recorded in the separate
`steamify-cachyos-dev` test plan on branch
`feature/steamdeck-hwmon-dkms-tests`. The product does not depend on that
repository.

### Automated tests

Local mock, fixture, and build tests cover:

- per-kernel provider detection, native/foreign providers, and conflicts;
- source staging, SHA-256 verification, DKMS configuration, and real module
  compilation against fixture kernel configurations;
- compact ownership state, package origins, restart markers, and invalid or
  lost state;
- fresh installation, idempotent re-apply, removal, and retained resources;
- interruptions around DKMS, package, autoload, state, mask, and recovery
  boundaries;
- terminal, backend, and QML parent/child planning, including fail-closed
  removal conflicts;
- controller and NVIDIA regression tests;
- Bash syntax, targeted ShellCheck, generated-bundle syntax and ShellCheck,
  `git diff --check`, and the offscreen QML toggle smoke test.

### CachyOS virtual machines

Independent overlays validated CachyOS standard and LTS kernels, including a
fresh install, interrupted install and recovery, idempotent re-apply, normal
removal, repeated removal, and the state after a guest reboot. Ownership cases
covered pre-existing and adopted Jupiter packages, Steamify-owned service
masks, missing or damaged state, and foreign DKMS providers.

A Deckify kernel with native `steamdeck` and `steamdeck_hwmon` was tested next
to standard and LTS kernels. Steamify preserved the native Deckify providers
and built only for the kernels with safe provider gaps.

The VM has no Valve embedded controller. It therefore cannot prove real ACPI
binding, hwmon readings, fan speed control, or firmware handoff.

### Valve Fremont Steam Machine

The feature commit `2e06a88e437c942924669a79dff5b894ff74a25e` was tested on a
real Valve Fremont Steam Machine with CachyOS standard `7.3.0-5` and LTS
`6.18.55-2` kernels.

- Installation through the Steamify terminal menu built and installed both
  modules for both kernels.
- After restart, both modules were loaded, `VLV0100:00` bound to `steamdeck`,
  `steamdeck_hwmon` exposed fan readings, and `jupiter-fan-control` ran.
- Steam's OS fan-control switch changed between OS and firmware control.
- OS mode: `fan1_target=500`, approximately 473 RPM, Jupiter active.
- Firmware mode: `fan1_target=0`, approximately 818 RPM, Jupiter inactive.
- Terminal removal confirmed a zero target, removed the owned Jupiter package,
  Steamify DKMS registration, and autoload file, and kept loaded modules until
  restart.
- After restart, the modules and Steamify DKMS registration were absent and
  `systemctl --failed` reported no failed units.
- Existing LED, HDMI-CEC, power-off, and parent Steam Machine functionality
  remained intact.

### Steamify QML app on Fremont

The local feature app was started directly through `ui/steamify-ui` on the
same hardware.

- The optional child appeared under Steam Machine support with a working detail
  view and scroll area.
- Installation and removal through the GUI succeeded.
- The `now on` state and pending-restart message matched the system state, and
  reopening the app detected the actual installed state.
- Turning the parent off produced the expected child-first plan with six
  disables. That plan was inspected but deliberately not applied.

Re-enabling a parent does not automatically restore every child that had been
selected earlier. This is existing general selection behavior and is outside
the scope of this feature.
