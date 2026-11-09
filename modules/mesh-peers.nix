# Addresses of the NordVPN Meshnet peers, keyed by bare hostname. `mesh` is the
# Meshnet IP and `lan` is the wired address at home.
#
# Single source of truth, consumed by:
#   home/shared/ssh.nix               -> the "<name>-mesh-ip" ssh match blocks
#                                        and the LAN-first match rules
#   home/workstation.nix              -> the RDP launcher
#   hosts/mac/meshnet-watchdog.nix    -> the peer it probes
#   hosts/mac/configuration.nix       -> the managed /etc/hosts block
#
# Only hosts that are actually registered on Meshnet belong here. rpi3 and mac
# are deliberately absent: neither `rpi3.nord` nor `mac.nord` resolves, so there
# is no address to record. Verify a host before adding it:
#
#   dig +short <name>.nord
#
# Mesh addresses are per-device assignments from NordVPN. They are stable for the
# life of a device's registration, but re-registering a machine will change its
# address.
{
  baremetal = { mesh = "100.125.97.192"; lan = "192.168.0.20"; };
  base = { mesh = "100.82.101.245"; lan = "192.168.0.3"; };
  bau = { mesh = "100.69.158.138"; lan = "192.168.0.6"; };
}
