# Raw sequencing reads

Not included in this repository. Download the paired-end FASTQ files for NCBI GEO accession GSE292174 and place them here, named to match the `fastq_R1` / `fastq_R2` columns of [`../metadata/sample_table.csv`](../metadata/sample_table.csv):

    NGS_CaKp/Ca1_1.fq.gz
    NGS_CaKp/Ca1_2.fq.gz
    ...

After downloading, verify the files against the bundled manifest:

    cd NGS_CaKp && md5sum -c md5checksums.txt

The checksums are for the FASTQ files as originally submitted. A mismatch may reflect
re-compression by GEO rather than a corrupted download; in that case, check the file
against the md5 checksum listed on GEO.

The Snakemake workflow reads this location from `abs_path` in [`../config/config.yaml`](../config/config.yaml).
