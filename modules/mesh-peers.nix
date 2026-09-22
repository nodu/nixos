# NordVPN Meshnet addresses, keyed by bare hostname.
#
# Single source of truth, consumed by:
#   home/shared/ssh.nix          -> the "<name>-mesh-ip" ssh match blocks
#   hosts/mac/configuration.nix  -> the managed /etc/hosts block
#
# Only hosts that are actually registered on Meshnet belong here. rpi3 and mac
# are deliberately absent: neither `rpi3.nord` nor `mac.nord` resolves, so there
# is no address to record. Verify a host before adding it:
#
#   dig +short <name>.nord
#
# These are per-device assignments from NordVPN. They are stable for the life of
# a device's registration, but re-registering a machine will change its address.
{
  baremetal = "100.125.97.192";
  bau = "100.69.158.138";
}
