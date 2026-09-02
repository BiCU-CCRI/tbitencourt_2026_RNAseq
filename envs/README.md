# Container images

All steps run inside pre-built images published on Docker Hub:

| image | used for | Docker Hub |
|---|---|---|
| `ccribioinf/rnaseq_core:v1.0` | fastp, STAR, samtools | https://hub.docker.com/r/ccribioinf/rnaseq_core |
| `ccribioinf/rnaseq_expression:v1.0` | salmon | https://hub.docker.com/r/ccribioinf/rnaseq_expression |
| `ccribioinf/dockrstudio:4.2.0-v1` | R 4.2.0 / RStudio Server for the downstream analysis | https://hub.docker.com/r/ccribioinf/dockrstudio |

## Building the Apptainer/Singularity images

The Snakemake workflow rules and `03_run_rstudio.sh` run using **Apptainer/Singularity** — Snakemake has no Docker-engine backend for per-rule containers.

Build the `.sif` files this repository expects into this `envs/` directory:

```
apptainer build envs/rnaseq_core_v1.0.sif        docker://ccribioinf/rnaseq_core:v1.0
apptainer build envs/rnaseq_expression_v1.0.sif  docker://ccribioinf/rnaseq_expression:v1.0
apptainer build envs/dockrstudio_4.2.0-v1.sif    docker://ccribioinf/dockrstudio:4.2.0-v1
```

Note: `apptainer build` reads the image directly from Docker Hub via the `docker://` prefix, so no Docker installation or `docker pull` is needed.

The `.sif` files are large and are **not** tracked in git (see `.gitignore`). Building them into `envs/` as above is all that is needed: the Snakemake workflow reads these paths from `config/config.yaml` (`core_container` / `expression_container`), and `01_build_reference.sh` uses the same paths for the index build. To keep the images elsewhere, edit those two keys in `config/config.yaml` and run `01_build_reference.sh` with `CORE_SIF` / `EXPRESSION_SIF` set to the new paths.

## Using Docker for the downstream R analysis

If you only want to run the downstream R analysis (Step 3) and would rather use Docker than Apptainer, pull just the RStudio image:

```
docker pull ccribioinf/dockrstudio:4.2.0-v1
```

See Step 3 in the top-level `README.md` for the `docker run` command. The workflow steps (fastp / STAR / salmon) are Apptainer-only.
