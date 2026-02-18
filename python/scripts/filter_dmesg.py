#!/usr/bin/env python3

import re
import socket
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils

# pylint: enable=wrong-import-position

BT_LE_CODED_PHY = r"Bluetooth: hci0: HCI LE Coded PHY feature bit is set, but its usage is not supported\."
PCI_OF_ROOT_NODE = 'PCI: OF: of_root node is NULL, cannot create PCI host bridge node'
AMDGPU_KVM_ERRORS = [
    r"amdgpu [0-9a-f:.]+ \[drm\] Failed to setup vendor infoframe on connector HDMI\-A\-1: \-22",
    r"amdgpu [0-9a-f:.]+ \[drm\] REG_WAIT timeout 1us \* 100000 tries \- optc\d+_disable_crtc line:\d+",
]
SYSTEMD_BPF_RESTRICT_FS = r"systemd\[1\]: bpf\-restrict\-fs: Failed to load BPF object: No such process"
READ_ALL_WARNINGS = [
    r"ICMPv6: process `read_all' is using deprecated sysctl \(syscall\) net\.ipv6\.neigh\.default\.base_reachable_time \- use net\.ipv6\.neigh\.default\.base_reachable_time_ms instead",
    'NOTICE: Automounting of tracing to debugfs is deprecated and will be removed in 2030',
    'WARNING! power/level is deprecated; use power/control instead',
    r"block [a-z0-9]+: the capability attribute has been deprecated\.",
    r"bdi [0-9a-f:]+ the stable_pages_required attribute has been removed\. Use the stable_writes queue attribute instead\.",
    r"warning: `read_all' uses wireless extensions which will stop working for Wi\-Fi 7 hardware; use nl80211",
]
NVME_WARNINGS = [
    r"block nvme\dn\d: No UUID available providing old NGUID",
    r"nvme nvme\d: missing or invalid SUBNQN field\.",
    r"nvme nvme\d: using unchecked data buffer",
]
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
        # Firmware bug according to intel_epb_restore()?
        "ENERGY_PERF_BIAS: Set to 'normal', was 'performance'",
        # ?
        r'spi-nor spi\d\.\d: supply vcc not found, using dummy regulator',
        # Don't care, I don't use SGX
        r"x86/cpu: SGX disabled or unsupported by BIOS\.",
        # BIOS issue?
        'hpet_acpi_add: no address or irqs in _CRS',
        # NVMe firmware issues?
        *NVME_WARNINGS,
        # Don't use IMA
        r"device\-mapper: core: CONFIG_IMA_DISABLE_HTABLE is disabled\. Duplicate IMA measurements will not be recorded in the IMA log\.",
        # Warnings that appear when using read_all to read /sys and /proc
        *READ_ALL_WARNINGS,
    ],
    'aadp': [
        # This machine does not use OF as far as I understand
        PCI_OF_ROOT_NODE,
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
        # New warning in 7.0, needs a bisect
        r"ACPI: CPU\d+: Invalid FFH LPI data",
        # BTF debug information is disabled because it takes extra time to build
        # and even if it were present, my configuration does not have support for it:
        # https://lore.kernel.org/20250610232418.GA3544567@ax162/
        SYSTEMD_BPF_RESTRICT_FS,
        # PCIe on this machine is wildly unreliable :/
        r"nvme [0-9a-f:.]+ PCIe Bus Error: severity=Correctable, type=Physical Layer, \(Receiver ID\)",
        r"nvme [0-9a-f:.]+\s+device \[[0-9a-f:]+\] error status/mask=00000001/0000e000",
        r"nvme [0-9a-f:.]+\s+\[ 0\] RxErr\s+\(First\)",
    ],
    'asus-intel-core-11700': [
        # This is not a shared client machine and I prefer having SMT on
        'MMIO Stale Data CPU bug present and SMT on, data leak possible',
    ],
    'beelink-amd-ryzen-8745HS': [
        # Happens when using a KVM
        *AMDGPU_KVM_ERRORS,
        # BIOS bugs more than likely, don't care
        r"ACPI BIOS Error \(bug\): Failure creating named object \[\\_SB\.PCI0\.GPP5\.RTL8\._S0W\], AE_ALREADY_EXISTS \(20251212/dswload2\-327\)",
        r"ACPI Error: AE_ALREADY_EXISTS, During name lookup/catalog \(20251212/psobject\-220\)",
        r"kvm_amd: \[Firmware Bug\]: Cannot enable x2AVIC, AVIC is unsupported",
        # Don't care, I don't use Bluetooth on this machine
        BT_LE_CODED_PHY,
    ],
    'beelink-intel-n100': [
        # Holy BIOS issues Batman!
        r"ACPI BIOS Error \(bug\): Could not resolve symbol \[\\_SB\.PC00\.TXHC\.RHUB\.SS0\d\], AE_NOT_FOUND \(20251212/dswload2\-163\)",
        r"ACPI Error: AE_NOT_FOUND, During name lookup/catalog \(20251212/psobject\-220\)",
        r"ACPI: thermal: \[Firmware Bug\]: No valid trip points!",
        r"resource: resource sanity check: requesting \[mem 0x00000000fe000000\-0x00000000fe001fff\], which spans more than INTC1023:00 \[mem 0xfe001210\-0xfe001247\]",
        r"resource: resource sanity check: requesting \[mem 0x00000000fedc0000\-0x00000000fedcffff\], which spans more than PNP0C02:02 \[mem 0xfedc0000\-0xfedc7fff\]",
        r"caller generic_core_init\+[0-9a-f/x]+ \[intel_pmc_core\] mapping multiple BARs",
        r"caller igen6_probe\+[0-9a-f/x]+ \[igen6_edac\] mapping multiple BARs",
        r"ACPI Warning: \\_SB\.PC00\.CNVW\._DSM: Argument #4 type mismatch \- Found \[Buffer\], ACPI requires \[Package\] \(20251212/nsarguments\-61\)",
        r"ACPI Warning: \\_SB\.PC00\.XHCI\.RHUB\.HS10\._DSM: Argument #4 type mismatch \- Found \[Integer\], ACPI requires \[Package\] \(20251212/nsarguments\-61\)",
    ],
    'chromebox3': [
        # This machine is riddled with vulnerabilities because it is Kaby Lake, don't care
        r"MDS CPU bug present and SMT on, data leak possible\. See https://www\.kernel\.org/doc/html/latest/admin\-guide/hw\-vuln/mds\.html for more details\.",
        r"MMIO Stale Data CPU bug present and SMT on, data leak possible\. See https://www\.kernel\.org/doc/html/latest/admin\-guide/hw\-vuln/processor_mmio_stale_data\.html for more details\.",
        r"VMSCAPE: SMT on, STIBP is required for full protection\. See https://www\.kernel\.org/doc/html/latest/admin\-guide/hw\-vuln/vmscape\.html for more details\.",
        # Don't have any USB devices plugged into this machine on the regular
        'usb: port power management may be unreliable',
        # ?
        r"cros\-ec\-cec cros\-ec\-cec\.\d\.auto: CEC notifier not configured for this hardware",
        # Audio configuration problems but don't care because audio is not used on this machine
        r"rt5663 i2c-[0-9A-F:]+ supply (?:a|cp)vdd not found, using dummy regulator",
        r"rt5663 i2c-[0-9A-F:]+ sysclk < 384 x fs, disable i2s asrc",
        r"snd_soc_avs [0-9a-z:.]+ Direct firmware load for intel/avs/hda\-8086280b\-tplg\.bin failed with error \-2",
        r'snd_soc_avs [0-9a-z:.]+ request topology "intel/avs/hda\-8086280b\-tplg\.bin" failed: \-2',
        r"avs_(hdaudio|rt5663) avs_(hdaudio|rt5663)\.\d+\.auto: ASoC: Parent card not yet available, widget card binding deferred",
    ],
    'framework-amd-ryzen-maxplus-395': [
        # Happens when using a KVM
        *AMDGPU_KVM_ERRORS,
        # The Framework Desktop does not have a PS2 port
        "i8042: Can't read CTR while initializing i8042",
        'i8042 i8042: probe with driver i8042 failed with error -5',
        # Don't care, I don't use Bluetooth on this machine
        r"Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported\.",
    ],
    'honeycomb': [
        # This machine does not use OF as far as I understand
        PCI_OF_ROOT_NODE,
        # Firmware problem?
        r"arm\-smmu arm\-smmu\.\d\.auto: Failed to disable prefetcher for errata workarounds, check SACR\.CACHE_LOCK",
        # ?
        r"fsl-mc dprc\.\d: DMA mask not set",
        # Should not matter for my usage of this machine
        r"ahci NXP[0-9:]+ supply (ahci|phy|target) not found, using dummy regulator",
        # Needs fix upstream from downstream driver?
        r"fsl_mc_dpio dpio\.\d+: unknown SoC version",
        # BTF debug information is disabled because it takes extra time to build
        # and even if it were present, my configuration does not have support for it:
        # https://lore.kernel.org/20250610232418.GA3544567@ax162/
        SYSTEMD_BPF_RESTRICT_FS,
    ],
    'msi-intel-core-10210U': [
        # Older Intel chip vulnerability
        r"MMIO Stale Data CPU bug present and SMT on, data leak possible\. See https://www\.kernel\.org/doc/html/latest/admin\-guide/hw\-vuln/processor_mmio_stale_data\.html for more details\.",
        # Old firmware with no upgrade path likely
        r"msi_ec: Firmware version is not supported: '1551EMS1\.104'",
        # Don't care, I don't use Bluetooth on this machine
        BT_LE_CODED_PHY,
        # Firmware issues, cannot care
        r"ACPI BIOS Error \(bug\): Could not resolve symbol \[\^\^\^RP05\.PEGP\], AE_NOT_FOUND \(20251212/psargs\-332\)",
        r"ACPI Error: Aborting method \\_SB\.PCI0\.LPCB\.EC\._QD1 due to previous error \(AE_NOT_FOUND\) \(20251212/psparse\-531\)",
        r"ACPI Error: No handler for Region \[VRTC\] \([0-9a-f]+\) \[SystemCMOS\] \(20251212/evregion\-131\)",
        r"ACPI Error: Region SystemCMOS \(ID=5\) has no handler \(20251212/exfldio\-261\)",
        r"ACPI Error: Aborting method \\_SB\.PCI0\.LPCB\.EC\._Q9A due to previous error \(AE_NOT_EXIST\) \(20251212/psparse\-531\)",
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
