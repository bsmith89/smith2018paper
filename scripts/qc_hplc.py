#!/usr/bin/env python3
import pandas as pd
from scipy.stats import linregress
import sys
from math import pi


def retention_deviation(data):
    out = data.set_index('molecule_id').dropna(subset=['retention_constant', 'tip'])
    # This checks if the injection/channel had no peaks.
    # TODO: What if it has just one peak?
    if out.empty:
        out['retention_deviation'] = float('nan')
    else:
        slope, intercept, *_ = linregress(out.retention_constant, out.tip)
        out['expected_tip'] = out.retention_constant * slope + intercept
        out['retention_deviation'] = (out.tip - out.expected_tip) / out.expected_tip
    return out.retention_deviation


def main():
    peak = pd.read_table(sys.argv[1])
    molecule = pd.read_table(sys.argv[2], index_col=0)
    out = (peak.join(molecule, on='molecule_id')
               .groupby(['injection_id', 'channel'])
               .apply(retention_deviation)
               .to_frame())

    peak['plates_hph'] = 5.54 * (peak.tip / peak.width_50) ** 2
    peak['plates_hph'] = peak['plates_hph'].replace(float('inf'), float('nan'))
    peak['plates_ah'] = 2 * pi * (peak.tip * peak.height / peak.area) ** 2
    peak = peak.set_index(['injection_id', 'molecule_id', 'channel'])

    out[['plates_hph', 'plates_ah']] = peak[['plates_hph', 'plates_ah']]
    out = out.reset_index().set_index(['injection_id', 'molecule_id', 'channel'])
    out.to_csv(sys.stdout, sep='\t')

if __name__ == "__main__":
    main()
