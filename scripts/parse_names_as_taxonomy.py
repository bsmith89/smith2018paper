#!/usr/bin/env python3
# res/%.clust.otu-tax.tsv: scripts/parse_names_as_taxonomy.py res/%.clust.names
# 	$^ unique otu-0.03 > $@

import sys

def main():
    taxon_level = sys.argv[2]
    taxon_level_b = sys.argv[3]
    print('taxon_id', 'taxon_level', 'taxon_id_b', 'taxon_level_b', 'confidence', sep='\t')
    with open(sys.argv[1]) as handle:
        for line in handle:
            taxon_id_b, subseqs_string = line.split('\t')
            for taxon_id in subseqs_string.strip().split(','):
                print(taxon_id, taxon_level, taxon_id_b, taxon_level_b, '100', sep='\t')


if __name__ == "__main__":
    main()

