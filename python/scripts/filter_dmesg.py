#!/usr/bin/env python3

import re
import socket
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils

# pylint: enable=wrong-import-position

ALLOWLIST = {
    'common': [
        # Happens when using Arch's default configuration with LTO enabled
        # because Rust cannot currently be enabled with BTF debug information
        r"Unsupported value for CONFIG_DRM_PANIC_SCREEN \('qr_code'\), falling back to 'user'\.\.\.",
        # Seems benign
        r"s[a-z] [0-9:]+ Power-on or device reset occurred",
        # regulatory.db may not exist, whatever
        r"faux_driver regulatory: Direct firmware load for regulatory\.db failed with error \-2",
        # EFI partition does not get properly unmounted sometimes?
        r"FAT\-fs \([a-z0-9]+\): Volume was not properly unmounted\. Some data may be corrupt\. Please run fsck\.",
        # Expected on certain platforms that do not expose ASPM control via firmware
        r"r8169 [0-9a-f:.]+ can't disable ASPM; OS doesn't have ASPM control",
        # Occasionally shows up under load
        r"hrtimer: interrupt took \d+ ns",
        # Happens when using a KVM
        r"amdgpu [0-9a-f:.]+ \[drm\] Failed to setup vendor infoframe on connector HDMI\-A\-1: \-22",
        r"amdgpu [0-9a-f:.]+ \[drm\] REG_WAIT timeout 1us \* 100000 tries \- optc\d+_disable_crtc line:\d+",
    ],
    'aadp': [
        # This machine does not use OF as far as I understand
        'PCI: OF: of_root node is NULL, cannot create PCI host bridge node',
        # Don't use IMA
        r"device\-mapper: core: CONFIG_IMA_DISABLE_HTABLE is disabled\. Duplicate IMA measurements will not be recorded in the IMA log\.",
        # Benign hardware warning?
        r"gpio-dwapb [A-Z0-9:]+ no IRQ for port0",
        # Expected given KPTI is on by default
        r'arm_spe_pmu arm,spe\-v1: profiling buffer inaccessible\. Try passing "kpti=off" on the kernel command line',
        r"arm_spe_pmu arm,spe\-v1: probe with driver arm_spe_pmu failed with error \-1",
        # The BMC in my AADP has been out of commission for a bit :(
        r"ipmi_si: Unable to find any System Interface\(s\)",
        r"ipmi_ssif i2c-[A-Z0-9:]+ ipmi_ssif: Not present",
        r"ipmi_ssif i2c-[A-Z0-9:]+ ipmi_ssif: Unable to start IPMI SSIF: \-19",
        # Appears to be something with the particular NVMe used in this machine
        r"nvme nvme0: using unchecked data buffer",
    ],
    'asus-intel-core-11700': [
        # This is not a shared client machine and I prefer having SMT on
        'MMIO Stale Data CPU bug present and SMT on, data leak possible',
        # Firmware bug according to intel_epb_restore()?
        "ENERGY_PERF_BIAS: Set to 'normal', was 'performance'",
        # ?
        r'spi-nor spi\d\.\d: supply vcc not found, using dummy regulator',
    ],
    'beelink-amd-ryzen-8745HS': [
        # BIOS bugs more than likely, don't care
        r"ACPI BIOS Error \(bug\): Failure creating named object \[\\_SB\.PCI0\.GPP5\.RTL8\._S0W\], AE_ALREADY_EXISTS \(20251212/dswload2\-327\)",
        r"ACPI Error: AE_ALREADY_EXISTS, During name lookup/catalog \(20251212/psobject\-220\)",
        r"kvm_amd: \[Firmware Bug\]: Cannot enable x2AVIC, AVIC is unsupported",
        # Don't care, I don't use Bluetooth on this machine
        r"Bluetooth: hci0: HCI LE Coded PHY feature bit is set, but its usage is not supported\.",
    ],
    'framework-amd-ryzen-maxplus-395': [
        # The Framework Desktop does not have a PS2 port
        "i8042: Can't read CTR while initializing i8042",
        'i8042 i8042: probe with driver i8042 failed with error -5',
        # Don't care, I don't use Bluetooth on this machine
        r"Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported\.",
    ],
}
ANSI_STRIP = re.compile(r'(?:\x1B[@-_]|[\x80-\x9F])[0-?]*[ -/]*[@-~]')

if __name__ == '__main__':
    dmesg_txt = None
    if not sys.stdin.isatty():
        dmesg_txt = sys.stdin.read()

    if (hostname := socket.gethostname()) not in ALLOWLIST:
        lib.utils.print_yellow(f"{hostname} not in ALLOWLIST, exiting...")
        if dmesg_txt:
            print(dmesg_txt, end='')
        sys.exit(0)

    if not dmesg_txt:
        lib.utils.request_root('accessing dmesg')
        dmesg_cmd = ['dmesg', '--color=always', '--level=warn+']
        dmesg_txt = lib.utils.run0(dmesg_cmd, capture_output=True).stdout

    allowlist = ALLOWLIST['common'] + ALLOWLIST[hostname]

    for dmesg_line in dmesg_txt.splitlines():
        escaped_line = ANSI_STRIP.sub('', dmesg_line)
        for regex in allowlist:
            if re.search(regex, escaped_line):
                break
        else:
            print(dmesg_line)
