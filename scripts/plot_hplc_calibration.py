#!/usr/bin/env python3

import matplotlib.pyplot as plt
from matplotlib import cm
import matplotlib.patches as mpatches
import pandas as pd
import seaborn as sns
import numpy as np
import argparse
import math
import sys
import sqlite3

SELECTOR_SEP = '='
DEFAULT_DPI = 120
COLOR_MAP = cm.viridis
MAX_WIDE_PLOTS = 4
PLOT_WIDTH = 4
PLOT_HEIGHT = 3

def frontend(argv):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('-s', '--subset',
                   metavar='FIELD{}VALUE'.format(SELECTOR_SEP),
                   dest='selectors', nargs='*', default=[])
    p.add_argument('-o', '--outfile', dest='outpath', type=str)
    p.add_argument('--dpi', type=int, default=DEFAULT_DPI)
    p.add_argument('database', metavar='DB', type=str)
    args = p.parse_args(argv)
    return args

def parse_selectors(selector_str_list, sep=SELECTOR_SEP):
    output = {}
    for pair in selector_str_list:
        first, second = pair.split(sep)
        output[first.strip()] = second.strip()
    return output

def subset(df, **kwargs):
    for col in kwargs:
        try:
            predicate = kwargs[col](df[col])
        except TypeError:
            predicate = (df[col] == kwargs[col])
        finally:
            df = df[predicate]
    return df

def load_stds(con):
    query = """
        SELECT
            injection_id
          , molecule_id
          , channel
          , calibration_group
          , known_concentration
          , peak_concentration.concentration
              AS calculated_concentration
        FROM known_injection
        JOIN known_metadata USING (known_id)
        JOIN peak_concentration USING (injection_id, molecule_id)
    """
    return pd.read_sql(query, con=con)

def load_unkn(con):
    query = """
        SELECT
            injection_id
          , molecule_id
          , channel
          , calibration_group
          , concentration
        FROM peak_concentration
        JOIN injection
          USING (injection_id)
        WHERE injection.fraction_known = 0
    """
    return pd.read_sql(query, con=con)

def grid_dims(n, dim_max=None):
    if dim_max:
        wide = min(n, dim_max)
        high = math.ceil(n / wide)
    else:
        wide = math.ceil(math.sqrt(n))
        high = math.ceil(n / wide)
    return wide, high

def main():
    args = frontend(sys.argv[1:])
    con = sqlite3.connect(args.database)
    selectors = parse_selectors(args.selectors)
    stds = subset(load_stds(con), **selectors)
    stds = stds.set_index(['molecule_id', 'channel', 'calibration_group'])
    unkn = subset(load_unkn(con), **selectors)
    unkn = unkn.set_index(['molecule_id', 'channel', 'calibration_group'])

    g = stds.groupby(level=['molecule_id', 'channel', 'calibration_group'])
    n = len(g)
    wide, high = grid_dims(n, MAX_WIDE_PLOTS)
    fig, axs = plt.subplots(high, wide,
                            figsize=(wide * PLOT_WIDTH,
                                     high * PLOT_HEIGHT),
                            sharex=True, sharey=True)
    for ((molecule_id, channel, calibration_group), _stds), ax1\
            in zip(g, axs.flatten()):
        _unkn = unkn.xs((molecule_id, channel, calibration_group))

        ax1.scatter(_stds.known_concentration,
                   (_stds.known_concentration - _stds.calculated_concentration) /
                        _stds.known_concentration)
        ax1.axhline(0, linestyle='--', color='black', lw=1)
        ax1.set_ylim(-0.5, 0.5)
        ax1.set_xscale('log')
        ax1.set_title((molecule_id, channel, calibration_group))
        ax1.fill_between([10**-2, 10**2], [-0.10, -0.10], [0.10, 0.10],
                         color='k', alpha=0.1)

        ax2 = ax1.twinx()
        ax2.grid(False)
        ax2.hist(_unkn.concentration.dropna(),
                 bins=np.logspace(-2, 2, 30, base=10), alpha=0.3)
        # ax2.set_yticks([1, 10])
        ax2.set_yticklabels([])
        ax2.set_ylim(0, 20)
        # ax2.yaxis.set_tick_params(length=5)

    fig.savefig(args.outpath, dpi=args.dpi)

if __name__ == '__main__':
    main()
