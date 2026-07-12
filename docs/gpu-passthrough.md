# NVIDIA Quadro P400 Passthrough Plan

Goal: pass the NVIDIA Quadro P400 from the Proxmox host through to the Debian Docker VM `docker01` so Jellyfin can use NVENC/NVDEC hardware transcoding.

## Current GPU detection status

### Inside Debian VM `docker01` - original state

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

Interpretation: Debian did not originally see the P400, and NVIDIA drivers were not installed in the VM.

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

Initial result before VFIO:

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

Interpretation: Proxmox sees the P400 and its HDMI/DisplayPort audio function.

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

## VFIO binding status

VFIO modules/config were added on the Proxmox host and initramfs was rebuilt.

After reboot, Proxmox host checks show:

```text
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP107GL [Quadro P400] [10de:1cb3] (rev a1)
        Subsystem: Dell Device [1028:11be]
        Kernel driver in use: vfio-pci
        Kernel modules: nvidiafb, nouveau
```

```text
01:00.1 Audio device [0403]: NVIDIA Corporation GP107GL High Definition Audio Controller [10de:0fb9] (rev a1)
        Subsystem: Dell Device [1028:11be]
        Kernel driver in use: vfio-pci
        Kernel modules: snd_hda_intel
```

Interpretation:

- The Proxmox host is no longer using `nouveau` or `snd_hda_intel` for the P400 functions.
- Both P400 functions are now bound to `vfio-pci`.

## VM attachment status

The P400 was added to the `docker01` VM as a raw PCI device from the Proxmox UI.

Recommended Proxmox PCI device settings used/planned:

| Option | Setting |
| --- | --- |
| Device | `0000:01:00.0 NVIDIA GP107GL [Quadro P400]` |
| All Functions | Checked |
| Primary GPU | Unchecked |
| ROM-Bar | Default / checked |
| PCI-Express | Checked if available; otherwise default |

Debian VM now sees the NVIDIA GPU with:

```bash
lspci | grep -i nvidia
```

Result:

```text
00:10.0 VGA compatible controller: NVIDIA Corporation GP107GL [Quadro P400] (rev a1)
00:10.1 Audio device: NVIDIA Corporation GP107GL High Definition Audio Controller (rev a1)
```

## NVIDIA driver status inside Debian

The Debian non-free repositories were enabled so `nvidia-driver` and `firmware-misc-nonfree` could be installed.

`nvidia-smi` now works inside `docker01`:

```text
NVIDIA-SMI 550.163.01             Driver Version: 550.163.01     CUDA Version: 12.4
GPU  Name                 Persistence-M | Bus-Id          Disp.A | Memory-Usage
0    Quadro P400                    Off | 00000000:00:10.0 Off | 2MiB / 2048MiB
```

Interpretation:

- Debian owns the P400 successfully.
- NVIDIA driver version `550.163.01` is working.

## NVIDIA Container Toolkit / Docker status

NVIDIA Container Toolkit was installed inside `docker01`.

Toolkit check:

```text
which nvidia-ctk
/usr/bin/nvidia-ctk

nvidia-ctk --version
NVIDIA Container Toolkit CLI version 1.19.1
```

Docker runtime configuration:

```json
{
    "runtimes": {
        "nvidia": {
            "args": [],
            "path": "nvidia-container-runtime"
        }
    }
}
```

Docker runtime check:

```text
Runtimes: io.containerd.runc.v2 nvidia runc
Default Runtime: runc
```

The generic `docker run --rm --gpus all ...` test returned an AMD CDI spec error, but the explicit NVIDIA runtime test works.

Successful Docker GPU test:

```bash
docker run --rm \
  --runtime=nvidia \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

Result:

```text
NVIDIA-SMI 550.163.01             Driver Version: 550.163.01     CUDA Version: 12.4
GPU  Name                 Persistence-M | Bus-Id          Disp.A | Memory-Usage
0    Quadro P400                     On | 00000000:00:10.0 Off | 2MiB / 2048MiB
```

Interpretation:

- Docker can access the P400 using the explicit NVIDIA runtime.
- Jellyfin Docker Compose should use `runtime: nvidia` plus NVIDIA environment variables rather than relying only on `--gpus all`.

## Jellyfin Docker Compose location

Active Compose file:

```text
/srv/docker/docker-compose.yml
```

Running containers:

```text
NAMES      IMAGE                      PORTS
caddy      caddy:latest               0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp, 443/udp, 2019/tcp
jellyfin   jellyfin/jellyfin:latest   0.0.0.0:8096->8096/tcp
```

Current NVIDIA-enabled Jellyfin Compose service:

```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=compute,video,utility
    ports:
      - "8096:8096"
    volumes:
      - /srv/docker/jellyfin/config:/config
      - /srv/docker/jellyfin/cache:/cache
      - /mnt/storage/media:/media
```

After running `docker compose up -d jellyfin`, Jellyfin started successfully and the container can see the GPU.

Test from inside the Jellyfin container:

```bash
docker exec jellyfin nvidia-smi
```

Result:

```text
NVIDIA-SMI 550.163.01             Driver Version: 550.163.01     CUDA Version: 12.4
GPU  Name                 Persistence-M | Bus-Id          Disp.A | Memory-Usage
0    Quadro P400                     On | 00000000:00:10.0 Off | 2MiB / 2048MiB
```

Interpretation:

- The Jellyfin container can see and use the P400.

## Jellyfin hardware transcoding status

Jellyfin Playback > Transcoding settings were enabled and saved for NVIDIA NVENC/NVDEC.

A forced transcode showed this in Jellyfin:

```text
Transcoding
Framerate: 18fps
3.0 Mbps MP4 H264 AC3
Reason for transcoding: The video's bitrate exceeds the limit
```

Before saving the Jellyfin settings, `nvidia-smi` showed no GPU process.

After saving the Jellyfin settings, `nvidia-smi` showed Jellyfin ffmpeg using the P400:

```text
GPU Memory-Usage: 91MiB / 2048MiB
Processes:
GPU  PID   Type   Process name                         GPU Memory
0    6288  C      /usr/lib/jellyfin-ffmpeg/ffmpeg       86MiB
```

Interpretation:

- Jellyfin hardware transcoding is confirmed working.
- The P400 is being used by `/usr/lib/jellyfin-ffmpeg/ffmpeg` during an active transcode.
- Remaining optional work: test a few codecs/clients, then clean up duplicate apt source warnings later.

## Next steps

1. Test a few different clients and files to confirm stable playback.
2. Keep HEVC encoding and tone mapping off for now unless there is a specific need.
3. Clean up duplicate `non-free-firmware` apt warnings later.
4. Move on to the next server task, likely Home Assistant OS VM migration.

## Notes

- Do not install NVIDIA drivers on the Proxmox host for this passthrough plan.
- The Proxmox host should keep the P400 bound to `vfio-pci`.
- The Debian VM should own the GPU after passthrough.
- If passthrough causes boot/display trouble, remove the PCI device from the VM and revert VFIO binding if needed.
- The duplicate `non-free-firmware` apt warnings should be cleaned up later, but they are not blocking Jellyfin GPU work.
