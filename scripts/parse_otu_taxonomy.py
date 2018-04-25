#!/usr/bin/env python3

import sys
import pandas as pd
import re
import numpy as np

LEVELS = [ 'domain'
         , 'phylum'
         , 'class'
         , 'order'
         , 'family'
         , 'genus'
         , 'species'
         , 'strain'
         ]


def main():
    if len(sys.argv) < 3:
        tax = pd.read_table(sys.stdin)
    else:
        tax = pd.read_table(sys.argv[2])
    tax.rename(columns={'OTU': 'taxon_id', 'Taxonomy': 'tax_string'}, inplace=True)
    tax.set_index('taxon_id', inplace=True)
    tax.drop(['Size'], axis='columns', inplace=True)

    n_levels = len(tax.tax_string[0].split(';')) - 1
    tax[LEVELS[:n_levels]] = (tax.tax_string
                                 .str.strip(';')
                                 .str.split(';')
                                 .apply(pd.Series)
                                 .replace('^\s*$', np.nan, regex=True))
    tax = tax.drop('tax_string', axis='columns')
    tax.columns.name = 'taxon_level_b'

    out = (tax.stack()
              .apply(lambda s: pd.Series(s.strip(')').split('(')))
              .reset_index()
              .rename(columns={0: 'taxon_id_b', 1: 'confidence'}))
    out['taxon_level'] = sys.argv[1]
    out = out[[ 'taxon_id'
              , 'taxon_level'
              , 'taxon_id_b'
              , 'taxon_level_b'
              , 'confidence' ]].drop_duplicates().reset_index(drop=True)

    out.to_csv(sys.stdout, sep='\t', index=False)

if __name__ == "__main__":
    main()
