# NVIDIA Quadro P400 Passthrough Plan

Goal: pass the NVIDIA Quadro P400 from the Proxmox host through to the Debian Docker VM `docker01` so Jellyfin can use NVENC/NVDEC hardware transcoding.

## Current GPU detection status

### Inside Debian VM `docker01`

Command:

```bash
lspci | grep -i nvidia
```

Result:

```text
No output
```

Command:

```bash
nvidia-smi
```

Result:

```text
-bash: nvidia-smi: command not found
```

Interpretation: Debian does not currently see the P400, and NVIDIA drivers are not installed in the VM.

### On Proxmox host `r515`

Command:

```bash
lspci | grep -i nvidia
```

Result:

```text
01:00.0 VGA compatible controller: NVIDIA Corporation GP107GL [Quadro P400] (rev a1)
01:00.1 Audio device: NVIDIA Corporation GP107GL High Definition Audio Controller (rev a1)
```

Command:

```bash
lspci -nnk | grep -A3 -i nvidia
```

Result:

```text
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP107GL [Quadro P400] [10de:1cb3] (rev a1)
        Subsystem: Dell Device [1028:11be]
        Kernel driver in use: nouveau
        Kernel modules: nvidiafb, nouveau
01:00.1 Audio device [0403]: NVIDIA Corporation GP107GL High Definition Audio Controller [10de:0fb9] (rev a1)
        Subsystem: Dell Device [1028:11be]
        Kernel driver in use: snd_hda_intel
        Kernel modules: snd_hda_intel
```

Interpretation: Proxmox sees the P400 and its HDMI/DisplayPort audio function. The host is currently binding the GPU to `nouveau` and the audio function to `snd_hda_intel`. For passthrough, the GPU functions should be bound to `vfio-pci` instead.

## Device IDs

| Function | PCI address | Device ID |
| --- | --- | --- |
| Quadro P400 GPU | `01:00.0` | `10de:1cb3` |
| NVIDIA audio function | `01:00.1` | `10de:0fb9` |

## IOMMU status

Command on Proxmox host:

```bash
dmesg | grep -e DMAR -e IOMMU -e AMD-Vi
```

Result:

```text
[    0.288523] AGP: Please enable the IOMMU option in the BIOS setup
[    0.685438] AMD-Vi: Using global IVHD EFR:0x0, EFR2:0x0
[    1.089808] AMD-Vi: Interrupt remapping enabled
```

Command on Proxmox host:

```bash
find /sys/kernel/iommu_groups/ -type l | grep 01:00
```

Result:

```text
/sys/kernel/iommu_groups/10/devices/0000:01:00.0
/sys/kernel/iommu_groups/10/devices/0000:01:00.1
```

Interpretation:

- IOMMU groups exist, so IOMMU is active enough for passthrough work.
- Both P400 functions are in IOMMU group `10`.

## IOMMU group 10 contents

Command on Proxmox host:

```bash
for d in /sys/kernel/iommu_groups/10/devices/*; do
  echo "---- $d ----"
  lspci -nnk -s "${d##*/}"
done
```

Result:

```text
---- /sys/kernel/iommu_groups/10/devices/0000:01:00.0 ----
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP107GL [Quadro P400] [10de:1cb3] (rev a1)
        Subsystem: Dell Device [1028:11be]
        Kernel driver in use: nouveau
        Kernel modules: nvidiafb, nouveau
---- /sys/kernel/iommu_groups/10/devices/0000:01:00.1 ----
01:00.1 Audio device [0403]: NVIDIA Corporation GP107GL High Definition Audio Controller [10de:0fb9] (rev a1)
        Subsystem: Dell Device [1028:11be]
        Kernel driver in use: snd_hda_intel
        Kernel modules: snd_hda_intel
```

Interpretation:

- IOMMU group `10` is clean.
- It contains only the P400 GPU and the P400 audio function.
- This is suitable for passing the whole GPU device to `docker01`.

## Next steps

1. Load VFIO modules.
2. Bind `10de:1cb3` and `10de:0fb9` to `vfio-pci`.
3. Blacklist host GPU drivers that claim the card, especially `nouveau`.
4. Rebuild initramfs and reboot Proxmox.
5. Confirm the P400 is using `vfio-pci` on the Proxmox host.
6. Add both GPU functions to the `docker01` VM as PCI devices.
7. Boot Debian and confirm `lspci | grep -i nvidia` sees the P400.
8. Install NVIDIA driver and NVIDIA Container Toolkit inside Debian.
9. Update Jellyfin Docker Compose to expose the GPU to Jellyfin.
10. Enable NVIDIA NVENC/NVDEC hardware acceleration in Jellyfin.

## Notes

- Do not install NVIDIA drivers on the Proxmox host for this passthrough plan.
- The Proxmox host should stop using `nouveau` for the P400.
- The Debian VM should own the GPU after passthrough.
- If passthrough causes boot/display trouble, revert the VFIO binding and remove the PCI device from the VM.
