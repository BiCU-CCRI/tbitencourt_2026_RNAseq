## Methods for bioinformatics analyses

Paired-end reads were trimmed for adapters and low-quality bases using fastp (v0.23.2; Chen et al., 2018), retaining only reads with a minimum length of 20. Genomic references and coding sequences for C. albicans SC5314 (GCF_000182965.3) and K. pneumoniae subs. MGH 78578 (GCF_000016305.1) were downloaded from NCBI Datasets (https://www.ncbi.nlm.nih.gov/datasets/genome/), combined into a single FASTA file, and indexed with Salmon (v1.9.0; Patro et al., 2017) using a k-mer length of 31 and reference sequences as decoys. Transcript-level quantification was subsequently performed with Salmon quant, where library type was automatically inferred. All downstream analyses were conducted in the R Statistical Software (v4.2.0; R Core Team, 2022). Transcript-level counts were summarized to gene-level counts using tximport (v1.26.1; Soneson et al., 2015). Genes with low expression across most of the samples were removed using the filterByExpr function and TMM normalization was applied using the calcNormFactors function from edgeR (v3.40.2; Robinson et al., 2010). Differential gene expression analysis was carried out with limma (v3.54.2; Law et al., 2014), where the mean-variance relationship was estimated and observation-level weights were computed using limma-voom prior to linear model fitting. Differentially expressed genes were identified based on empirical Bayes moderated t-statistics with multiple testing correction by the Benjamini-Hochberg method. Statistical significance thresholds were set at an absolute fold change >1.5 and an adjusted p value <0.05. Biological Process GO term enrichment was conducted using TopGO (v2.50.0; Alexa and Rahnenführer., 2009), with significant terms identified by the weight01 algorithm and Fisher’s exact test. KEGG Over-Representation Analysis and Gene Set Enrichment Analysis were performed with clusterProfiler (v4.6.2; Yu et al., 2012). Enrichment plots were generated with gseaplot2 from the enrichplot package (v1.18.4; Wu et al., 2021), KEGG pathway maps were visualized with pathview (v1.38.0; Luo et al., 2013) and Venn diagrams were created using the eulerr package (v7.0.2; Larsson, 2024).

## References

Chen, Shifu, Yanqing Zhou, Yaru Chen, and Jia Gu. "fastp: an ultra-fast all-in-one FASTQ preprocessor." Bioinformatics 34, no. 17 (2018): i884-i890.

Patro, Rob, Geet Duggal, Michael I. Love, Rafael A. Irizarry, and Carl Kingsford. "Salmon provides fast and bias-aware quantification of transcript expression." Nature methods 14, no. 4 (2017): 417-419.

R Core Team (2022). R: A language and environment for statistical computing. R Foundation for Statistical Computing, Vienna, Austria. URL https://www.R-project.org/.

Charlotte Soneson, Michael I. Love, Mark D. Robinson (2015): Differential analyses for RNA-seq: transcript-level estimates improve gene-level inferences. F1000Research

Robinson, Mark D., and Alicia Oshlack. "A scaling normalization method for differential expression analysis of RNA-seq data." Genome biology 11 (2010): 1-9.

Law, Charity W., Yunshun Chen, Wei Shi, and Gordon K. Smyth. "voom: Precision weights unlock linear model analysis tools for RNA-seq read counts." Genome biology 15 (2014): 1-17.

Alexa, Adrian, and Jörg Rahnenführer. "Gene set enrichment analysis with topGO." Bioconductor Improv 27 (2009): 1-26.

Yu, Guangchuang, Li-Gen Wang, Yanyan Han, and Qing-Yu He. "clusterProfiler: an R package for comparing biological themes among gene clusters." Omics: a journal of integrative biology 16, no. 5 (2012): 284-287.

Wu, Tianzhi, Erqiang Hu, Shuangbin Xu, Meijun Chen, Pingfan Guo, Zehan Dai, Tingze Feng et al. "clusterProfiler 4.0: A universal enrichment tool for interpreting omics data." The innovation 2, no. 3 (2021).

Luo, Weijun, and Cory Brouwer. "Pathview: an R/Bioconductor package for pathway-based data integration and visualization." Bioinformatics 29, no. 14 (2013): 1830-1831.

Larsson J (2024). _eulerr: Area-Proportional Euler and Venn Diagrams with Ellipses_. R package version 7.0.2, <https://CRAN.R-project.org/package=eulerr>.
