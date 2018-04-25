#!/usr/bin/env python3

import sys

def main():
    label = sys.argv[1]
    otus_path = sys.argv[2]
    with open(otus_path) as handle:
        for line in handle:
            if line.startswith('label'):  # Header
                otu_names = line.strip().split('\t')[2:]
            elif line.startswith(label):  # Our row of interest
                seq_groups = line.strip().split('\t')[2:]
                break
        else:
            raise AssertionError("The requested label, {}, was not found.".format(label))

    for name, group in zip(otu_names, seq_groups):
        print(name, group.strip(), sep='\t', file=sys.stdout)

if __name__ == "__main__":
    main()
