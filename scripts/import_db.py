#!/usr/bin/env python3

import pandas as pd
import sys
import sqlite3
import collections
import argparse
import os

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--script', '--schema', '--sql', '-s',
                   type=argparse.FileType('r'), 
                   action='append', default=[], metavar='SQL',
                   help='SQL script to run before importing tables')
    p.add_argument('--table', '-t',
                   metavar='TABLE=PATH',
                   help='tablename-filename pairs to import',
                   action='append', default=[])
    p.add_argument('--db-out-path',
                   help='database file (will be over-written)',
                   default=':memory:')
    p.add_argument('--dump-sql', help='dump SQL to stdout', action='store_true')
    args = p.parse_args()

    sqlite3.enable_callback_tracebacks(True)
    table_map = collections.OrderedDict()
    for mapping in args.table:
        key, value = mapping.split('=')
        table_map[key.strip()] = value.strip()

    if args.db_out_path != ':memory:':
        try:
            os.remove(args.db_out_path)
        except FileNotFoundError:
            pass
        else:
            print("Removing existing db file.", file=sys.stderr)
    conn = sqlite3.connect(args.db_out_path)

    curs = conn.cursor()
    for handle in args.script:
        script = handle.read()
        curs.executescript(script)
    curs.close()

    for table in table_map:
        df = pd.read_table(table_map[table])
        try:
            df.to_sql(table, conn, if_exists='append', index=False)
        except sqlite3.Error as err:
            print("Error while import table {}".format(table), file=sys.stderr)
            raise err
        del df

    # Dump the sql script
    if args.dump_sql:
        for line in conn.iterdump():
            print(line, file=sys.stdout)

    conn.close()


if __name__ == "__main__":
    main()
