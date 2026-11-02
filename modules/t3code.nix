# T3 Code pinned to the latest stable release. scripts/update-t3code.sh bumps
# t3code.json; the build recipe comes from the nixpkgs-t3code flake input.
{ lib, rustPlatform, t3code }:

let
  pin = lib.importJSON ./t3code.json;

  unwrapped = t3code.unwrapped.overrideAttrs (finalAttrs: old: {
    inherit (pin) version;
    src = old.src.override {
      tag = "v${finalAttrs.version}";
      hash = pin.srcHash;
    };
    pnpmDeps = old.pnpmDeps.overrideAttrs {
      inherit (finalAttrs) version src;
      outputHash = pin.pnpmDepsHash;
    };
    # Pairing-issued sessions expire after a fixed 30 days with no refresh, so
    # every client must re-pair monthly. Drop once upstream ships a fix:
    # https://github.com/pingdotgg/t3code/issues/13055
    # https://github.com/pingdotgg/t3code/issues/9884
    postPatch = (old.postPatch or "") + ''
      substituteInPlace apps/server/src/auth/SessionStore.ts \
        --replace-fail "DEFAULT_SESSION_TTL = Duration.days(30)" "DEFAULT_SESSION_TTL = Duration.days(365)"
    '';
  });
in
t3code.override {
  t3code-unwrapped = unwrapped;
  t3code-resource-monitor = t3code.resourceMonitor.overrideAttrs (old: {
    inherit (unwrapped) version src;
    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit (unwrapped) src;
      inherit (old) sourceRoot;
      hash = pin.cargoHash;
    };
  });
}
