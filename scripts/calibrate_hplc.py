#!/usr/bin/env python3

import pandas as pd
import numpy as np
import statsmodels.formula.api as sm
import sqlite3
import sys


def relative_standard_error(fit):
    data = pd.DataFrame(dict(residual=fit.resid,
                             fitted=fit.predict()))
    data['deviation_ratio'] = data.residual / data.fitted
    return np.sqrt(np.sum(data.deviation_ratio ** 2) / fit.df_resid)

def get_calibration(data):
    data = data.copy()
    try:
        data['weight'] = data.known_concentration ** -2
    except ZeroDivisionError:
        data['weight'] = np.nan
    data = data.replace([np.inf, -np.inf], np.nan).dropna(subset=['weight', 'area'])
    if not len(data) > 1:
        return

    # Deal with presence/absence of an intercept term according to calibration_config
    _intercept = data.intercept.unique()
    assert len(_intercept) == 1
    intercept = _intercept[0]

    try:
        if intercept == 0:
            fit = sm.wls('area ~ known_concentration - 1', data=data, weights=data.weight).fit()
        else:
            fit = sm.wls('area ~ known_concentration', data=data, weights=data.weight).fit()
    except ValueError as err:
        print(data, file=sys.stderr)
        raise err

    out = {}
    if hasattr(fit.params, 'Intercept'):
        out['intercept'] = fit.params.Intercept
        out['slope'] = fit.params[1]
    else:
        out['intercept'] = 0
        out['slope'] = fit.params[0]
    out['limit_of_detection'] = np.nan  # TODO
    out['observations'] = fit.nobs
    out['relative_standard_error'] = relative_standard_error(fit)
    out['rsquared'] = fit.rsquared

    return pd.Series(out)

def main():
    con = sqlite3.connect(sys.argv[1])
    meta_query = """
        SELECT *
        FROM known_injection_metadata
        JOIN calibration_group
          USING (injection_id)
        JOIN calibration_config
          USING (molecule_id)
    """
    meta = pd.read_sql(meta_query, con=con)
    peak = pd.read_table(sys.argv[2])
    data = peak.merge(meta, on=['injection_id', 'molecule_id', 'channel'])
    calibration = (data.groupby(['molecule_id', 'channel', 'calibration_group'])
                       .apply(get_calibration))
    calibration.to_csv(sys.stdout, sep='\t')

if __name__ == '__main__':
    main()
