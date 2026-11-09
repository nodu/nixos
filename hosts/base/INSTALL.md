# Installing NixOS on base

NixOS takes the whole NVMe (1G ESP + one root partition), replacing both
Ubuntu and the bare-metal Windows install. Windows 11 comes back as a fresh
libvirt VM that borrows the RTX 3090 while it runs.

GPUs: the GTX 1080 (`05:00.0`, chipset slot) drives the host desktop. The RTX
3090 (`01:00.0`, CPU x16 slot) does host CUDA (Unsloth Studio) and goes to the VM while
the VM is up. The 3090 is the boot VGA card, so firmware screens (BIOS, the
systemd-boot menu, the installer) come out of it. The VM's display does too.
Cable the monitor to both cards and switch inputs.

## 1. Before wiping

- Copy anything wanted off Ubuntu (`/home/matt` is 18G: `Code`, `notes`,
  `dotenv`, `Documents`, ...) and off the Windows partition:
  `rsync -aHAX --info=progress2 /home/matt/ /mnt/usb/ubuntu-home/`
- Reserve `192.168.0.3` for the desktop in the router.

## 2. Make the installer USB (on the Mac)

Any USB stick of 4 GB or more; it gets erased. The minimal ISO is enough, since
every step below is a shell command.

```bash
cd ~/Downloads
curl -LO https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso
curl -L https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso.sha256
shasum -a 256 latest-nixos-minimal-x86_64-linux.iso   # must match the hash above

diskutil list external physical      # find the stick, e.g. /dev/disk4
diskutil unmountDisk /dev/diskN
sudo dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/rdiskN bs=4m status=progress
diskutil eject /dev/diskN
```

Use `rdiskN` (raw device, much faster) and double-check `N`: `dd` overwrites
whatever disk it is given.

## 3. Wipe the NVMe and install (NixOS 26.05 ISO)

Plug the stick and ethernet into the desktop, cable the monitor to the 3090,
and press F8 at power-on. Pick the `UEFI: <stick>` entry, not the plain one
(that's legacy BIOS mode, and systemd-boot needs UEFI). Secure Boot is already
off. The ISO auto-logs in as `nixos` and gets an address by DHCP.

Optional: to paste the commands below from the Mac instead of typing them, run
`passwd` (sets a password for `nixos`) and `ip -br a` on the desktop, then
`ssh nixos@<ip>` from the Mac.

```bash
sudo -i
lsblk -o NAME,SIZE,FSTYPE,PARTLABEL /dev/nvme0n1   # confirm it's the 238G Samsung

sgdisk --zap-all /dev/nvme0n1
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:NIXBOOT /dev/nvme0n1
sgdisk -n 2:0:0   -t 2:8300 -c 2:nixos   /dev/nvme0n1
partprobe /dev/nvme0n1
mkfs.fat -F 32 -n NIXBOOT /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/nvme0n1p2

mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/NIXBOOT /mnt/boot

# Stale firmware entries for the old Windows Boot Manager and ubuntu
efibootmgr
efibootmgr -b XXXX -B       # once per stale entry

# Compare against the hand-written hardware-configuration.nix; copy over any
# kernel modules it adds, but keep the by-label filesystems
nixos-generate-config --root /mnt --show-hardware-config

mkdir -p /mnt/home/matt/repos
nix-shell -p git --run 'git clone https://github.com/nodu/nixos.git /mnt/home/matt/repos/nixos'
nixos-install --flake /mnt/home/matt/repos/nixos#base --no-root-passwd

nixos-enter --root /mnt -c 'passwd matt; chown -R matt:users /home/matt'
reboot
```

## 4. First boot

The systemd-boot menu shows on the 3090's output; the desktop appears on the
**1080's**.

`ssh base` from the Mac works straight away: base authorizes the same key the
Mac and baremetal use. `backup.tar.gz` is gitignored, so the fresh clone on
base doesn't have it. Make a fresh one on baremetal: the copy in the Mac's repo
is from March and may be missing newer `~/.secrets`. Paths in the archive are
relative to `$HOME`, so it unpacks into `/home/matt` on base wherever it was
made. From the Mac:

```bash
ssh baremetal 'cd ~/repos/nixos && make secrets/backup'   # ~/.ssh, ~/.gnupg, ~/.secrets
# (do the ~/.ssh/matt rename on baremetal first, so the backup has the new name)
scp baremetal:repos/nixos/backup.tar.gz /tmp/ && scp /tmp/backup.tar.gz base:repos/nixos/
rm /tmp/backup.tar.gz
```

Then on base:

```bash
cd ~/repos/nixos
make secrets/restore        # unpacks backup.tar.gz into ~
make switch                 # NIXNAME defaults to the hostname. Also re-links
                            # ~/.ssh/config, which the restore overwrote with
                            # baremetal's (dangling) home-manager symlink
rm backup.tar.gz            # private keys; don't leave a copy lying around

nvidia-smi                  # both GPUs, driver 580.x; no process on the 3090

# The 3090's IOMMU group should hold just 01:00.0, 01:00.1 and root port 00:01.0
for d in /sys/kernel/iommu_groups/*/devices/*; do
  g=${d#*/iommu_groups/}; echo "group ${g%%/*}: $(lspci -nns ${d##*/})"
done | sort -V
```

- `nordvpn login`, enable Meshnet, set the nickname to `base`, then update its
  IP in `modules/mesh-peers.nix` if registering gave it a new one (`ssh base`
  uses the Meshnet name).
- Enable "Restore AC Power Loss: Power On" in the BIOS so the box comes back
  after a power cut.

## 5. Create the Windows 11 VM

Download the Windows 11 ISO (microsoft.com/software-download/windows11) and
the virtio-win ISO (fedorapeople.org, `virtio-win.iso`).

In virt-manager: New VM > Local install media > the Windows 11 ISO. Name it
**`win11`**: the GPU hook in `hosts/base/configuration.nix` only acts on that
name. Give it 16 GB RAM and 6 vCPUs, and a 128G disk (qcow2 in
`/var/lib/libvirt/images`, which grows as used). Tick "Customize configuration
before install":

- Overview: chipset Q35, firmware UEFI with Secure Boot (`...secboot...`).
- CPUs: host-passthrough, topology 1 socket / 3 cores / 2 threads.
- Disk: bus VirtIO. Add a second CD-ROM with `virtio-win.iso`. In setup, "Load
  driver" from it so the disk shows up.
- Add Hardware > TPM: emulated, CRB, v2.0.
- Add Hardware > PCI Host Device: `0000:01:00.0` and `0000:01:00.1` (3090 and
  its audio). virt-manager adds them as `managed='yes'`, which is what makes
  libvirt move the card between nvidia and vfio-pci.
- Add Hardware > USB Host Device for a keyboard and mouse, or keep the SPICE
  display until Windows has the NVIDIA driver and then remove it.

After installing, add the virtio guest tools from `virtio-win.iso` and the
NVIDIA driver inside Windows.

## Using it

Quit Unsloth Studio (or unload its model) first, then start `win11`
(virt-manager, or `virsh start win11`). The hook checks that nothing still has
the 3090 open, and libvirt moves the card to vfio-pci. If something does hold
it, the start fails with the process list instead of hanging. Shut Windows down
and the 3090 returns to the host: `nvidia-smi` lists it again.

If the handoff misbehaves (the detach hangs, or the card doesn't come back
after shutdown), boot the `vfio-boot` entry. It gives the 3090 to vfio-pci from
early boot, so the VM always works, but the host has no CUDA on it.
