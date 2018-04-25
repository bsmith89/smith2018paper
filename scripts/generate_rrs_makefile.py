#!/usr/bin/env python3

import sys
import sqlite3
import pandas as pd

def main():
    db = sqlite3.connect(sys.argv[1])
    libraries = pd.read_sql("SELECT * FROM rrs_library",
                            con=db)
    for lib, sra_id in libraries[['rrs_library_id', 'sra_id']].values:
        print('raw/rrs/{lib}.rrs.r1.fastq.gz raw/rrs/{lib}.rrs.r2.fastq.gz: SRA_ID := {sra_id}'.format(lib=lib, sra_id=sra_id))

    groups = pd.read_sql("SELECT * FROM rrs_library JOIN rrs_analysis_group USING (rrs_library_id)", con=db)
    for analysis_group, d in groups.groupby('analysis_group'):
        all_fn_splits = ' '.join('seq/split/{lib}.rrs.fuse.fn'.format(lib=lib) for lib in d.rrs_library_id)
        print(('seq/{analysis_group}.rrs.fuse.fn: '
               '{all_fn_splits}\n'
               '\tcat $^ > $@').format(analysis_group=analysis_group, all_fn_splits=all_fn_splits))
        all_groups_splits = ' '.join('res/split/{lib}.rrs.fuse.groups'.format(lib=lib) for lib in d.rrs_library_id)
        print(('res/{analysis_group}.rrs.fuse.groups: '
               '{all_groups_splits}\n'
               '\tcat $^ > $@').format(analysis_group=analysis_group, all_groups_splits=all_groups_splits))

if __name__ == '__main__':
    main()
