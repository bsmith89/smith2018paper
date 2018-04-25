#!/usr/bin/env python3

import pandas as pd
import sys

def main():
    shared = pd.read_table(sys.argv[1])

    shared['rrs_library_id'] = shared.Group
    shared = shared.drop('Group', axis='columns')
    shared['taxon_level'] = shared['label'].apply(lambda x: 'otu-{}'.format(x))
    shared = shared.drop('label', axis='columns')
    shared = shared.drop('numOtus', axis='columns')


    shared = shared.set_index(['rrs_library_id', 'taxon_level'])
    shared = shared.stack()
    shared = shared[shared != 0]
    shared.name = 'tally'
    shared = shared.to_csv(sys.stdout,
                           sep='\t',
                           header=True,
                           index_label=('rrs_library_id', 'taxon_level', 'taxon_id'))

if __name__ == "__main__":
    main()
