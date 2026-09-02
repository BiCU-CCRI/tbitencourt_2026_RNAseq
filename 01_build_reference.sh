#!/bin/bash
# Step 1 of the pipeline: build the hybrid C. albicans + K. pneumoniae reference.
# Produces the combined FASTA / GTF / GFF, the STAR and salmon indexes, and derived annotation files used by the downstream R analysis.
#
# usage:  bash 01_build_reference.sh 2>&1 | tee 01_build_reference.log
#
# Requirements:
#   * apptainer or singularity on PATH (loaded below if your cluster uses modules)
#   * the rnaseq_core / rnaseq_expression containers as .sif files (see envs/README.md)
#   * python3 (only the standard library is used by the helper scripts)
#
# Container images (override if your .sif files live elsewhere):
CORE_SIF="${CORE_SIF:-envs/rnaseq_core_v1.0.sif}"                    # STAR
EXPRESSION_SIF="${EXPRESSION_SIF:-envs/rnaseq_expression_v1.0.sif}"  # salmon

set -euo pipefail

# Environment (cluster-specific -- edit as needed). apptainer/singularity must be on PATH; if your cluster uses environment modules, load it here.
if type module >/dev/null 2>&1; then
  module load apptainer || true
fi

container_cmd="$(command -v apptainer || command -v singularity || true)"
if [ -z "${container_cmd}" ]; then
  echo "ERROR: neither apptainer nor singularity found on PATH" >&2
  exit 1
fi

cd reference

# ---------------------------------------------------------------------------
# 1. Reference source files
#    C. albicans SC5314          GCF_000182965.3  (ASM18296v3)
#    K. pneumoniae MGH 78578     GCF_000016305.1  (ASM1630v1)
#    https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_000182965.3/
#    https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_000016305.1/
#
#    For reproducibility, this repository includes the exact downloaded NCBI genome/annotation files used for the published analysis (gzipped, in th reference/ directeory).
# ---------------------------------------------------------------------------
require() {
  local plain="$1"
  if [ ! -f "$plain" ] && [ ! -f "${plain}.gz" ]; then
    echo "ERROR: missing reference file: reference/${plain}(.gz)" >&2
    echo "       This repository ships the exact genome/annotation files behind the published" >&2
    echo "       analysis; see reference/README.md." >&2
    exit 1
  fi
}

for f in GCF_000182965.3_ASM18296v3_genomic.fna \
         GCF_000182965.3_ASM18296v3_genomic.gtf \
         GCF_000182965.3_ASM18296v3_genomic.gff \
         GCF_000182965.3_ASM18296v3_cds_from_genomic.fna \
         GCF_000182965.3_ASM18296v3_gene_ontology.gaf \
         GCF_000182965.3_ASM18296v3_feature_table.txt \
         GCF_000016305.1_ASM1630v1_genomic.fna \
         GCF_000016305.1_ASM1630v1_genomic.gtf \
         GCF_000016305.1_ASM1630v1_genomic.gff \
         GCF_000016305.1_ASM1630v1_cds_from_genomic.fna \
         GCF_000016305.1_ASM1630v1_feature_table.txt; do
  require "$f"
done

gunzip -kf ./*.gz

# ---------------------------------------------------------------------------
# 2. Combined genome FASTA and GTF (GTF is used for the STAR index)
# ---------------------------------------------------------------------------
cat GCF_000182965.3_ASM18296v3_genomic.fna \
    GCF_000016305.1_ASM1630v1_genomic.fna \
    > GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_genomic.fna

grep -v "^#" GCF_000182965.3_ASM18296v3_genomic.gtf \
    >  GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_genomic.gtf
grep -v "^#" GCF_000016305.1_ASM1630v1_genomic.gtf \
    >> GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_genomic.gtf

# ---------------------------------------------------------------------------
# 3. Combined GFF3 (used by GenomicFeatures in the R analysis). The single-organism
#    K. pneumoniae GFF is also kept for the geneid2go step below.
# ---------------------------------------------------------------------------
grep -v "^#" GCF_000182965.3_ASM18296v3_genomic.gff \
    >  GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_genomic.gff
grep -v "^#" GCF_000016305.1_ASM1630v1_genomic.gff \
    >> GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_genomic.gff

# ---------------------------------------------------------------------------
# 4. Combined CDS FASTA (K. pneumoniae has no transcripts FASTA, CDS is used)
# ---------------------------------------------------------------------------
cat GCF_000182965.3_ASM18296v3_cds_from_genomic.fna \
    GCF_000016305.1_ASM1630v1_cds_from_genomic.fna \
    > GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_cds.fna

cd ..

# ---------------------------------------------------------------------------
# 5. STAR genome index (reads are 150 bp -> sjdbOverhang 149)
#    genomeSAindexNbases 11 is the value recommended by STAR for this genome size.
# ---------------------------------------------------------------------------
genomedir="reference/STAR_index_149bp"
mkdir -p "$genomedir"
"$container_cmd" exec --bind "$(pwd)" "$CORE_SIF" \
  STAR --runThreadN 4 \
    --runMode genomeGenerate \
    --genomeDir "$genomedir" \
    --genomeSAindexNbases 11 \
    --genomeFastaFiles reference/GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_genomic.fna \
    --sjdbGTFfile reference/GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_genomic.gtf \
    --sjdbOverhang 149 2> >(tee reference/star_index_log.txt >&2)

# ---------------------------------------------------------------------------
# 6. salmon index (decoy-aware: CDS + whole genome as decoy)
# ---------------------------------------------------------------------------
grep "^>" reference/GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_genomic.fna \
  | cut -d " " -f1 | sed -e 's/>//g' > reference/decoys.txt
cat reference/GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_cds.fna \
    reference/GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_genomic.fna \
    > reference/GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_cds_and_genomic.fna
mkdir -p reference/salmon_index
"$container_cmd" exec --bind "$(pwd)" "$EXPRESSION_SIF" \
  salmon index --threads 4 \
    --transcripts reference/GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_cds_and_genomic.fna \
    --index reference/salmon_index/GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_cds_and_genomic_k31 \
    --kmerLen 31 \
    --decoys reference/decoys.txt 2> >(tee reference/salmon_index_log.txt >&2)

# ---------------------------------------------------------------------------
# 6b. Verify the salmon index matches the one behind the published analysis.
# ---------------------------------------------------------------------------
salmon_info="reference/salmon_index/GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_cds_and_genomic_k31/info.json"
actual_hash="$(grep -oE '"SeqHash": *"[0-9a-f]+"' "$salmon_info" | grep -oE '[0-9a-f]{64}')"
expected_hash="f10eb0891d2072d74e315d12aeaa010611d622c6c81775d354aba1a1cda5f66b"
echo "salmon index SeqHash: ${actual_hash}"
if [ "$actual_hash" != "$expected_hash" ]; then
  echo "ERROR: salmon index built from the reference files does not match the expected (expected ${expected_hash}, got ${actual_hash})." >&2
  exit 1
fi
echo "OK: matches the expected reference index."

# ---------------------------------------------------------------------------
# 7. Derived annotation files used by the downstream R analysis
#    (these files are already committed to this repository)
# ---------------------------------------------------------------------------
# transcript -> gene map for tximport
python scripts/create_tx2gene_from_cds_fa.py \
  reference/GCF_000182965.3_ASM18296v3__GCF_000016305.1_ASM1630v1_cds.fna

# gene -> GO term maps for topGO
python scripts/create_geneid2go_mappings_for_klebsiella.py \
  reference/GCF_000016305.1_ASM1630v1_genomic.gff
python scripts/create_geneid2go_mappings_for_candida.py \
  reference/GCF_000182965.3_ASM18296v3_gene_ontology.gaf \
  reference/GCF_000182965.3_ASM18296v3_feature_table.txt
