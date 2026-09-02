#!/bin/bash
# Step 2 of the pipeline: run the alignment + quantification workflow (workflow/Snakefile).
# Runs fastp trimming, STAR alignment and decoy-aware salmon quantification for every sample in metadata/sample_table.csv.
#
# usage:         bash 02_run_snakemake.sh 2>&1 | tee 02_run_snakemake.log
# usage (SLURM): sbatch --partition=<queue> --qos=<queue> 02_run_snakemake.sh
#
# Requirements:
#   * snakemake and apptainer/singularity on PATH (loaded below if your cluster uses modules, else activate the environment you installed snakemake into)
#   * the containers named in config/config.yaml as .sif files (see envs/README.md)
#   * Step 1 (01_build_reference.sh) completed -- the salmon index must exist
#
# SLURM directives below are a starting point -- adjust the resources and queue for your cluster.
# Running `bash 02_run_snakemake.sh` ignores them.
#SBATCH --job-name=rnaseq_snakemake
#SBATCH --time=3-00:00:00
#SBATCH --mem=32G
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --output=rnaseq_snakemake.out
#SBATCH --error=rnaseq_snakemake.err

set -euo pipefail

ncores="${NCORES:-16}"

# Environment (cluster-specific -- edit as needed). snakemake and apptainer/singularity must be on PATH; if your cluster uses environment modules, load them here.
if type module >/dev/null 2>&1; then
  module load snakemake apptainer || true
fi

command -v snakemake >/dev/null || { echo "ERROR: snakemake not found on PATH" >&2; exit 1; }
command -v apptainer >/dev/null || command -v singularity >/dev/null || {
  echo "ERROR: neither apptainer nor singularity found on PATH" >&2; exit 1; }

snakemake --cores "$ncores" \
        --rerun-incomplete \
        --keep-going \
        --use-singularity \
        --singularity-args "--bind $(pwd):$(pwd)"
