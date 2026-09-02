# *Candida albicans* – *Klebsiella pneumoniae* biofilm co-culture RNA-seq

Bulk RNA-seq analysis of *Candida albicans* and *Klebsiella pneumoniae* grown as **single-species** and **mixed-species** cultures in two media (RPMI and M9), with four or more replicates per culture–medium combination. Samples were quantified against a combined *C. albicans* + *K. pneumoniae* reference. The aim of this work is to identify the pathways and biological processes in each organism that are altered by inter-species interaction, by comparing mixed cultures against the corresponding single cultures.

This repository enables reproduction of the analysis end to end: a Snakemake workflow for read trimming, alignment and transcript quantification, and an R Markdown report for the downstream differential-expression, GO, and KEGG analyses.

Reproducing this analysis:

1. **Prerequisites** — build the container images and download the input data (below).
2. **Step 1** — build the reference genome and indexes.
3. **Step 2** — run the Snakemake workflow (trimming, alignment, quantification).
4. **Step 3** — run the R Markdown downstream analysis.

You can start at Step 3 using the salmon quantifications from GEO — see *Input data* below.

## Prerequisites

### Software

The following must be available on the host (they are not provided by the containers):

* **Singularity/Apptainer** — runs the container images (usually available as a system module on HPC clusters; Docker is an alternative for Step 3, see below). Tested with Apptainer **1.1.9**.
* **Snakemake** — orchestrates Step 2. Tested with **7.18.2** and **8.20.6**; other versions are untested. Install e.g. with conda/mamba (`mamba create -n snakemake -c conda-forge -c bioconda 'snakemake=7.18.2'`) or load your cluster's snakemake module, then run Step 2 from within that environment.
* **python3** (standard library only) — used by `01_build_reference.sh` in Step 1.

Step 3 runs inside the `dockrstudio` container, which provides **R 4.2.0**. The R packages are then installed into a project-local library by `renv::restore()` from the pinned versions in [`candida_klebsiella_diff_expression_analysis/renv.lock`](candida_klebsiella_diff_expression_analysis/renv.lock).

### Container images

Three images (published on Docker Hub) are used. These are run via **Singularity/Apptainer**.  Build the required `.sif` files as described in [`envs/README.md`](envs/README.md):

* `ccribioinf/rnaseq_core:v1.0` — fastp, STAR, samtools (Steps 1–2)
* `ccribioinf/rnaseq_expression:v1.0` — salmon (Steps 1–2)
* `ccribioinf/dockrstudio:4.2.0-v1` — R 4.2.0 / RStudio Server (Step 3)

### Input data

Raw sequencing reads are deposited at NCBI GEO under accession [**GSE292174**](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE292174).

* Download the paired-end FASTQ files and place them under `NGS_CaKp/`. Ensure that they are named to match `metadata/sample_table.csv`, i.e. `<sample>_1.fq.gz` and `<sample>_2.fq.gz` (e.g. `Ca1_1.fq.gz`, `Ca1_2.fq.gz`).
* GEO also hosts the per-sample **salmon quantifications** as supplementary files (`GSM*_<sample>_quant.sf.gz`). If you only want to reproduce the downstream R analysis, you can skip the Snakemake workflow (Steps 1–2): download those, and place each as `results/expression/salmon_quant/<sample>_quant/quant.sf`.
* The downstream analysis **excludes two outlier RPMI mixed-culture samples, `CaKp3` and `CaKp4`** (set in the R Markdown using the variable `exclude_samples`).

## Step 1 — Build the reference and indexes

Ensure `apptainer`/`singularity` is on your `PATH` (or edit the `module load` line near the top of the script).

```bash
bash 01_build_reference.sh 2>&1 | tee 01_build_reference.log
```

This step builds the combined FASTA / GTF / GFF, the STAR and salmon indexes (using the `rnaseq_core` / `rnaseq_expression` containers), and the small annotation files used downstream. The combined genome and index files are not tracked in git. See [`reference/README.md`](reference/README.md) for more information.

**Expected output:** the STAR index (`reference/STAR_index_149bp/`) and salmon index (`reference/salmon_index/`), as well as the small derived annotation files required for the R analysis (tx2gene map, gene-to-GO mappings — see [`reference/README.md`](reference/README.md)). This script also checks that the newly built salmon index `SeqHash` matches the salmon index hash from the published analysis — look for `OK: matches the expected reference index.` near the end of `01_build_reference.log`.

## Step 2 — Alignment and quantification (Snakemake)

Ensure `snakemake` and `apptainer`/`singularity` are on your `PATH` (or edit the `module load` line near the top of the script). The `#SBATCH` directives in the script are a template; adjust the resources and queue for your cluster. The full workflow was run on one node with 16 cores and 32 GB RAM, taking ~2-3 days wall-clock depending on cluster load; peak memory was ~32 GB.

```bash
bash 02_run_snakemake.sh 2>&1 | tee 02_run_snakemake.log         # run directly, or
sbatch --partition=<queue> --qos=<queue> 02_run_snakemake.sh     # via SLURM
```

Note: If the SLURM job hits the `--time` limit before finishing, you can resubmit the same command with `sbatch` as the script already passes `--rerun-incomplete` and so Snakemake picks up from the steps already completed instead of starting over. Raise `--time` in the script if this happens repeatedly.

This step runs the workflow in [`workflow/Snakefile`](workflow/Snakefile) for every sample in `metadata/sample_table.csv`:

1. `fastp` — adapter/quality trimming, minimum read length 20
2. `STAR` — genome alignment (not used downstream but produced for QC)
3. `salmon quant` — decoy-aware transcript quantification, library type auto-detected

See [`config/config.yaml`](config/config.yaml) for the workflow parameters and configurations.

**Expected output:** per sample, trimmed FASTQs + fastp report (`results/data_processed/fastq_trimmed/`, `results/reports/`), a sorted/indexed STAR BAM (`results/data_processed/star_aligned/`), and salmon transcript-level quantification (`results/expression/salmon_quant/<sample>_quant/quant.sf`) — the last is what Step 3 reads. `02_run_snakemake.log` (and `rnaseq_snakemake.out`/`.err` under SLURM) should end with Snakemake reporting all rules complete; per-rule logs are under `logs/`.

## Step 3 — Downstream analysis (R)

This step can be run directly using the salmon transcript-level quantifications downloaded from GEO.

### Step 3.1 - Start the Rstudio Server container

Ensure `apptainer`/`singularity` is on your `PATH` (or edit the `module load` line near the top of the script), then start RStudio Server in the container:

```bash
bash 03_run_rstudio.sh                                     # run directly, or
sbatch --partition=<queue> --qos=<queue> 03_run_rstudio.sh # via SLURM
```

This starts a foreground RStudio Server, so submit it to an interactive/dev queue rather than a batch queue if running on SLURM. To stop the RStudio Server, use Ctrl-C, or for a SLURM job - either `scancel <jobid>` or via the SLURM time limit.

The `#SBATCH` directives in the script are a template; adjust the resources and queue for your cluster. The script prints a `http://<host>:<port>` URL (port picked from 8000–9000, which many clusters route to compute nodes; change the range with `PORT_MIN` / `PORT_MAX`, or pin one with `RSTUDIO_PORT`). Open it directly if your cluster routes browser traffic to compute nodes, otherwise forward the port from your workstation first with `ssh -N -L 8787:<host>:<port> <user>@<login-node>` and open `http://localhost:8787`.

`03_run_rstudio.sh` uses Apptainer/Singularity. If you have Docker instead, run the RStudio Server container directly from the repository root:

```bash
docker pull ccribioinf/dockrstudio:4.2.0-v1

docker run --rm \
        -p 8787:8787 \
        -e USER="$(whoami)" -e USERID="$(id -u)" \
        -e GROUP="$(whoami)" -e GROUPID="$(id -g)" \
        -e PASSWORD=<password> \
        --volume="$(pwd)":/home/"$(whoami)" \
        ccribioinf/dockrstudio:4.2.0-v1
```

Then open `http://<host>:8787` and log in with your username and `<password>`. This mounts the repository into the container so its files are accessible from RStudio.

### Step 3.2 - Install required packages

Within RStudio, open the project `candida_klebsiella_diff_expression_analysis/candida_klebsiella_diff_expression_analysis.Rproj` and restore the R library with `renv::restore()`

### Step 3.3 - Run the Rmarkdown analysis

 Knit the Rmarkdown [`candida_klebsiella_diff_expression_analysis/Candida_Klebsiella_RNAseq_Analysis_Revised.Rmd`](candida_klebsiella_diff_expression_analysis/Candida_Klebsiella_RNAseq_Analysis_Revised.Rmd) by running the command `rmarkdown::render("Candida_Klebsiella_RNAseq_Analysis_Revised.Rmd")` in the RStudio console. A rendered copy of the report (`.html`) is included alongside it for reference.

This script runs the following analysis: `tximport` (summarize transcript quantification → gene) → `edgeR` (`filterByExpr`, TMM normalization) → `limma-voom` differential expression (|fold change| > 1.5, adjusted *p* < 0.05) → `topGO` GO enrichment, `clusterProfiler` KEGG over-representation and GSEA, `pathview` pathway maps, and `eulerr` Venn diagrams.

**Expected output:** the rendered report `candida_klebsiella_diff_expression_analysis/Candida_Klebsiella_RNAseq_Analysis_Revised.html`, plus a `candida_klebsiella_diff_expression_analysis/candida_klebsiella_rnaseq_analysis_results*/` directory with the DE tables, GO/KEGG enrichment results, pathview maps, and figures (these result/figure directories are not tracked in git — see `.gitignore`).

### Additional analysis inputs

| file | description |
| --- | --- |
| `metadata/table_from_tamires.xlsx` | sample design table (group/media/replicate factors) |
| `candida_klebsiella_diff_expression_analysis/TF_biofilm_Ca.txt` | curated *C. albicans* biofilm transcription factors |
| `candida_klebsiella_diff_expression_analysis/hyphal_genes.txt`, `cwi_genes.txt`, `ram_genes.txt` | curated candidate gene sets (hyphal growth, cell-wall integrity, RAM pathway) |
| `candida_klebsiella_diff_expression_analysis/CaOrtholog_23Sep23_Raju_PCT_TFs.txt` | *C. albicans* transcription-factor KEGG IDs, extracted with `scripts/parse_tfs.py` from an ortholog/GO table (genes whose GO annotation contains "transcription factor \| DNA binding"). |

## Methods

See [`Methods.md`](Methods.md) for the methods and tool references.
