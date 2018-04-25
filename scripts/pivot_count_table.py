#!/usr/bin/env python3
# Convert a MOTHUR formatted count table into a "sparse" read_count tsv.

# import pandas as pd
import sys

def main():
    with open(sys.argv[1]) as handle:
        header_line = next(handle)
        library_ids = header_line.split()[2:]
        print('rrs_library_id', 'taxon_level', 'taxon_id', 'tally',
              sep='\t', file=sys.stdout)
        for line in handle:
            taxon_id, _, *tallies = line.split()
            for library_id, tally in zip(library_ids, tallies):
                if tally != '0':
                    print(library_id, 'unique', taxon_id, tally, sep='\t',
                          file=sys.stdout)


if __name__ == "__main__":
    main()
