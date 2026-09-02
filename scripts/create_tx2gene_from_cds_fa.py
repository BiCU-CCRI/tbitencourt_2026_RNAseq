import sys
import os

if len(sys.argv)<2:
    print("usage: create_tx2gene_from_cds_fa.py cds.fasta")
    exit()
infile=sys.argv[1]
outfile=os.path.splitext(infile)[0]+"_tx2gene.tsv"
with open(infile) as f, open(outfile,'w') as o:
    for line in f:
        if not line.startswith(">"):
            continue
        info=line.strip().split(" ")
        txname=info[0][1:]
        for entry in info[1:3]:
            if "locus_tag" in entry:
                geneid=entry.split("=")[1][:-1]
                outstr=txname+"\t"+geneid+"\n"
                o.write(outstr)

