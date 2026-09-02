import sys
import os

if len(sys.argv)<3:
    print("usage: python create_geneid2go_mappings_for_candida.py <gaf_file> <feature_table_file>")
    print("usage: python create_geneid2go_mappings_for_candida.py reference/GCF_000182965.3_ASM18296v3_gene_ontology.gaf reference/GCF_000182965.3_ASM18296v3_feature_table.txt")
    exit()
gaffile=sys.argv[1]
featurefile=sys.argv[2]
outfile=os.path.splitext(gaffile)[0]+"_geneid2go_mappings.tsv"

genego_lookup={}
with open(gaffile) as g:
    for line in g:
        if line.startswith('!'):
            if line.startswith('!#'):
                header=line.strip().split("\t")
                geneid_ind=header.index("GeneID")
                go_ind=header.index("GO_ID")
            else:
                continue
        info=line.strip().split("\t")
        geneid=line.strip().split("\t")[geneid_ind]
        goid=line.strip().split("\t")[go_ind]
        if geneid in genego_lookup:
            genego_lookup[geneid].append(goid)
        else:
            genego_lookup[geneid]=[goid]
geneids_written=[]
with open(featurefile) as f, open(outfile,'w') as o:
    for line in f:
        if line.startswith("#"):
            header=line.strip().split("\t")
            geneid_ind=header.index("GeneID")
            locustag_ind=header.index("locus_tag")
        else:
            geneid=line.strip().split("\t")[geneid_ind]
            locustag=line.strip().split("\t")[locustag_ind]
            if geneid in geneids_written:
                continue
            if geneid in genego_lookup:
                goterms=",".join(genego_lookup[geneid])
                outstr=locustag+"\t"+goterms+"\n"
                o.write(outstr)
                geneids_written.append(geneid)