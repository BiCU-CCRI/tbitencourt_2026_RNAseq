# common functions
def fq_input(wildcards, abs_path = '.', column_name='fastq'):
    # bam_filename - path to ubam file
    # abs_path - path to raw files
    # fastq_R1
    # fastq_R2
    #FIXME:
    # [ ] - add check for abs_path
    # [ ] - add check for samples variable
    return abs_path + samples.loc[wildcards.sample, column_name]


# def get_fastqs(wildcards, sample_layout, absolute_path):
#     """
#     Modified Celine P. function!

#     #FIXME:
#     # [ ] - for now hardcoding for 'paired'
#     """
#     sample_layout="paired"
#     fq_output = dict()
#     if sample_layout == "single":
#         fq_output["fq"] = absolute_path+samples.loc[wildcards.sample, "fastq"] # files[wildcards.samples]
#     elif sample_layout == "paired":
#         fq_output["fq_R1"] = absolute_path+samples.loc[wildcards.sample, "fastq_R1"]
#         fq_output["fq_R2"] = absolute_path+samples.loc[wildcards.sample, "fastq_R2"]
#     return fq_output


# def get_meta_pathinfo(wildcards, metadata, col):
#     return config['abs_path'] + metadata.loc[wildcards.sample, col]

# def get_mem_mb(wildcards, threads):
#     # mem_mb=lambda wildcards, threads: 100 * threads
#     return threads * 4000, #4GB