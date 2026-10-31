# Data science: Jupyter and the common scientific Python stack
#
# The environment is built from pkgs.python3 and uses pkgs.uv, the same
# derivations devops.nix installs, so there is one interpreter version on the
# host. Listing pkgs.uv again is harmless: it is the same store path.
#
# pythonEnv and devops.nix's bare pkgs.python3 both ship bin/python3, which
# would collide in the profile. hiPrio makes the env with libraries win, so
# `python3` on PATH can import everything below.
#
# For per-project dependencies, use a uv venv instead of adding them here.
{ config, lib, pkgs, ... }:

let
  pythonEnv = pkgs.python3.withPackages (ps: [
    # Notebooks
    ps.jupyterlab
    ps.notebook
    ps.ipykernel
    ps.ipywidgets

    # Data frames and arrays
    ps.numpy
    ps.pandas
    ps.polars
    ps.pyarrow

    # Stats and ML
    ps.scipy
    ps.statsmodels
    ps.scikit-learn
    ps.sympy

    # Plotting
    ps.matplotlib
    ps.seaborn
    ps.plotly

    # Utilities
    ps.requests
    ps.tqdm
  ]);
in
{
  home.packages = [
    (lib.hiPrio pythonEnv)
    pkgs.uv
  ];
}
