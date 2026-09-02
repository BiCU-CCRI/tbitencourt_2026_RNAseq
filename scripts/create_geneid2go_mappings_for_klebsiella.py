import sys
import os

if len(sys.argv)<2:
    print("usage: python create_geneid2go_mappings_for_klebsiella.py <gff_file>")
    print("usage: python create_geneid2go_mappings_for_klebsiella.py reference/GCF_000016305.1_ASM1630v1_genomic.gff")
    exit()
gfffile=sys.argv[1]
outfile=os.path.splitext(gfffile)[0]+"_geneid2go_mappings.tsv"
locustags_written=[]

with open(gfffile) as g, open(outfile,'w') as o:
    for line in g:
        if line.startswith('#'):
            continue
        info=line.strip().split("\t")[8]
        for entry in info.split(";"):
            if entry.split("=")[0]=="locus_tag":
                locustag=entry.split("=")[1]
            if entry.split("=")[0]=="Ontology_term":
                goterms=entry.split("=")[1]
                if locustag in locustags_written:
                    continue
                outstr=locustag+"\t"+goterms+"\n"
                o.write(outstr)
                locustags_written.append(locustag)