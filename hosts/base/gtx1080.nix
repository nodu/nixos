# GTX 1080 (Pascal, sm_61) as a third compute card next to the RTX 3090s.
# Import from configuration.nix, together with home/base-gtx1080.nix in
# home-base.nix.
{ config, ... }:

{
  # Pascal has no open kernel module, and the 590+ drivers (`production` is 595
  # in 26.05) dropped it. 580 is NVIDIA's long-term branch for
  # Maxwell/Pascal/Volta, supported until Aug 2028, and drives the 3090s too.
  hardware.nvidia = {
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };
}
