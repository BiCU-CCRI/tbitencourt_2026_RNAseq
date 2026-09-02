# This script parses the table provided by Tamires "CaOrtholog_23Sep23_Raju_PCT.csv" based on her description:
# 'It would be best to search on GO term with "transcription factor | Dna binding"'
import sys
import os
import csv

if len(sys.argv)<2:
    print("usage: python parse_tfs.py CaOrtholog_23Sep23_Raju_PCT.csv")
    exit()
infile=sys.argv[1]
outfile=os.path.splitext(infile)[0]+"_TFs.txt"

gokeys=['GO_BP','GO_CC','GO_MF']
tf_terms=['transcription factor', 'dna binding']
with open(infile) as f, open(outfile,'w') as o:
    reader = csv.DictReader(f)
    for line in reader:
        if any(tf_term in goterm for goterm in [line.get(gokey).lower() for gokey in gokeys] for tf_term in tf_terms):
            o.write(line['Cal_KEGG_ID']+"\n")


