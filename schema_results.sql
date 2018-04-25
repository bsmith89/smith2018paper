/*
 * Project: longev
 * Syntax: SQLite3
 *
 * Tables and views which can be fully loaded without any data.
 * Mirrors content in etc/*, which is version controlled.
 *
 * Tables are usually named based on their primary key.
 * If the primary key is just one column, that column is called `*_id`
 * If it is a compound primary key, then it is given a name:
 *
 * calibration: (molecule_id, channel, [calibration_group])
 * peak: (injection_id, molecule_id, channel)
 *
 */

-- Pragmas {{{1
PRAGMA foreign_keys = ON;

-- Tables {{{1
-- hplc {{{2
CREATE TABLE peak
  ( injection_id TEXT REFERENCES injection(injection_id)
  , molecule_id     TEXT REFERENCES molecule(molecule_id)
  , channel      TEXT       -- {RI, UV_VIZ}
  , tip          FLOAT      -- Retention time at the peak of the
                            -- + curve: the greatest distance from baseline
  , left         FLOAT      -- Retention time at start of integration
  , right        FLOAT      -- Retention time at end of integration
  , area         FLOAT      -- Area under the curve
  , height       FLOAT      -- Distance from the baseline at the peak
  , width_05     FLOAT      -- Width at 5% of height
  , width_10     FLOAT      -- Width at 10% of height
  , width_50     FLOAT      -- Width at 50% of height

  , PRIMARY KEY (injection_id, molecule_id, channel)
  );

CREATE TABLE peak_qc
  ( injection_id          TEXT REFERENCES injection(injection_id)
  , molecule_id              TEXT REFERENCES molecule(molecule_id)
  , channel               TEXT
  , retention_deviation   FLOAT     -- Ratio of the residual to the expected
                                    -- + retention time based on regression
                                    -- + against the expected relative retention
                                    -- + times for all peaks
  , plates_hph            FLOAT     -- Theoretical number of plates,
                                    -- + Half Peak Height method
  , plates_ah             FLOAT     -- Theoretical number of plates,
                                    -- + Area Height method

  , PRIMARY KEY (injection_id, molecule_id, channel)
  );


CREATE TABLE calibration
  ( molecule_id                TEXT REFERENCES molecule(molecule_id)
  , channel                 TEXT
  , calibration_group       TEXT
  , slope                   FLOAT     -- Slope of the standard curve
  , intercept               FLOAT     -- Intercept of the standard curve
  , observations            INTEGER   -- Number of points included in fitting
                                      -- + the standard curve
  , rsquared                FLOAT     -- Fit parameter of the standard curve
  , relative_standard_error FLOAT     -- Relative standard error
                                      -- + (does this include point weighting...?)
  , limit_of_detection      FLOAT     -- Lowest concentration at which the
                                      -- + relative standard error is within
                                      -- + some threshold.

  , PRIMARY KEY (molecule_id, channel, calibration_group)
  );

-- rrs {{{2
CREATE TABLE _rrs_library_taxon_count
  ( rrs_library_id      TEXT REFERENCES rrs_library(rrs_library_id)
  , taxon_level     TEXT            -- Taxon clustering threshold
                                    -- + e.g. 'otu-0.03', 'otu-0.05', 'genus', 'family'
  , taxon_id        TEXT            -- The id of the taxon (usually an OTU)
  , tally           INTEGER

  , PRIMARY KEY (rrs_library_id, taxon_level, taxon_id)
  );
CREATE INDEX idx_rrs_library_taxon_count__taxon_id ON _rrs_library_taxon_count(taxon_id);
CREATE INDEX idx_rrs_library_taxon_count__taxon_level ON _rrs_library_taxon_count(taxon_level);
CREATE INDEX idx_rrs_library_taxon_count__tally ON _rrs_library_taxon_count(tally);


CREATE TABLE taxonomy
  ( taxon_id        TEXT  -- Focal sequence/OTU/taxon name
  , taxon_level     TEXT  -- The level of the focal taxon
  , taxon_id_b      TEXT  -- The parent sequence/OTU/taxon
  , taxon_level_b   TEXT  -- The level of the parent
  , confidence      FLOAT  -- The level of confidence that the focal
                           -- taxon is in the parent taxon

  , PRIMARY KEY (taxon_id, taxon_level, taxon_id_b, taxon_level_b)
  );
  CREATE INDEX idx_taxonomy__taxon_id_b ON taxonomy(taxon_id_b);
  CREATE INDEX idx_taxonomy__taxon_level ON taxonomy(taxon_level);
  CREATE INDEX idx_taxonomy__taxon_level_b ON taxonomy(taxon_level_b);

CREATE TABLE rrs_spike_strain_hit
  ( taxon_id      TEXT
  , taxon_level   TEXT
  , spike_seq_id  TEXT

  );

-- Views {{{1
-- hplc {{{2

CREATE VIEW peak_concentration AS
  SELECT
      injection_id
    , molecule_id
    , channel
    , calibration_group
    , (area - c.intercept) / slope AS concentration
  FROM calibration AS c
  JOIN calibration_config AS f
    USING (molecule_id, channel)
  JOIN calibration_group AS g
    USING (calibration_group)
  LEFT JOIN peak AS p
    USING (injection_id, molecule_id, channel)
;

CREATE VIEW injection_concentration AS
  SELECT
      injection_id
    , molecule_id
    , channel
    , AVG(concentration) AS concentration   -- TODO: Make this a weighted mean
                                            -- + to account for the different
                                            -- + standard errors between
                                            -- + calibration groups.
    , COUNT(concentration) AS groups_count
  FROM peak_concentration
  LEFT JOIN unknown_injection_metadata
    USING (injection_id)
  GROUP BY injection_id, molecule_id, channel
;

CREATE VIEW extraction_concentration AS
  SELECT
      extraction_id
    , molecule_id
    , channel
    , AVG(concentration) AS concentration
    , COUNT(concentration) AS injection_count
  FROM injection_concentration
  LEFT JOIN unknown_injection
    USING (injection_id)
  LEFT JOIN extraction
    USING (extraction_id)
  LEFT JOIN peak_qc
    USING (injection_id, molecule_id, channel)
  WHERE extraction_id IS NOT NULL
  GROUP BY extraction_id, molecule_id, channel
;

CREATE VIEW sample_concentration AS
  SELECT
      sample_id
    , molecule_id
    , channel
    , AVG(result.concentration * extraction.volume / extraction.weight)
        AS concentration
    , COUNT(concentration) AS extraction_count
  FROM extraction_concentration AS result
  LEFT JOIN extraction_metadata AS extraction
    USING (extraction_id)
  WHERE sample_id IS NOT NULL
  GROUP BY sample_id, molecule_id, channel
;

CREATE VIEW mouse_concentration AS
  SELECT
      mouse_id
    , molecule_id
    , channel
    , AVG(concentration) AS concentration
    , COUNT(concentration) AS sample_count
  FROM sample_concentration
  LEFT JOIN sample_metadata
    USING (sample_id)
  WHERE mouse_id IS NOT NULL
  GROUP BY mouse_id, molecule_id, channel
;

CREATE VIEW cage_concentration AS
  SELECT
      cage_id
    , molecule_id
    , channel
    , AVG(concentration) AS concentration
    , COUNT(concentration) AS mouse_count
  FROM mouse_concentration
  LEFT JOIN mouse_metadata
    USING (mouse_id)
  WHERE cage_id IS NOT NULL
  GROUP BY cage_id, molecule_id, channel
;

-- rrs {{{2

-- Per sample list of taxa that originated in the spike.
CREATE VIEW rrs_library_spike_taxon AS
  SELECT DISTINCT rrs_library_id, taxon_level, taxon_id, spike_seq_id
  FROM rrs_library
  JOIN extraction USING (extraction_id)
  JOIN spike USING (spike_id)
  JOIN rrs_spike_strain_hit USING (spike_seq_id)
;

-- Number of libraries with sequences from each taxon
CREATE VIEW rrs_library_taxon_incidence AS
  SELECT taxon_level, taxon_id, COUNT(*) AS incidence
  FROM _rrs_library_taxon_count
  WHERE tally > 0
  GROUP BY taxon_level, taxon_id
;

-- Filtered count table with singleton taxa and spike taxa removed.
CREATE VIEW rrs_library_taxon_count AS
  SELECT r.*
  FROM _rrs_library_taxon_count AS r
  LEFT JOIN rrs_library_spike_taxon AS s USING (rrs_library_id, taxon_level, taxon_id)
  LEFT JOIN rrs_library_taxon_incidence USING (taxon_level, taxon_id)
  WHERE incidence > 1
    AND s.spike_seq_id IS NULL
;

-- Sum of all reads NOT from a spike.
CREATE VIEW rrs_library_endemic_total AS
  SELECT
      rrs_library_id
    , taxon_level
    , SUM(tally) AS total
  FROM _rrs_library_taxon_count
  LEFT JOIN rrs_library_spike_taxon USING (rrs_library_id, taxon_id, taxon_level)
  GROUP BY rrs_library_id, taxon_level, spike_seq_id
  HAVING spike_seq_id IS NULL
;

-- Sum of all reads from each spike.
CREATE VIEW rrs_library_spike_total AS
  SELECT
      rrs_library_id
    , taxon_level
    , spike_seq_id
    , SUM(tally) AS total
  FROM _rrs_library_taxon_count
  LEFT JOIN rrs_library_spike_taxon USING (rrs_library_id, taxon_id, taxon_level)
  GROUP BY rrs_library_id, taxon_level, spike_seq_id
  HAVING spike_seq_id NOT NULL
;

-- Relative abundance of all endemic taxa.
CREATE VIEW rrs_library_taxon_relative_abundance AS
  SELECT
      rrs_library_id
    , taxon_level
    , taxon_id
    , CAST(tally AS FLOAT) / total AS relative_abundance
  FROM rrs_library_taxon_count
  LEFT JOIN rrs_library_endemic_total
    USING (rrs_library_id, taxon_level)
;

-- Absolute abundance of all endemic taxa.
CREATE VIEW rrs_library_taxon_absolute_abundance AS
  SELECT
      rrs_library_id
    , taxon_level
    , taxon_id
    , spike_seq_id
    , (tally * spike_volume) / (total * extraction_weight)
        AS absolute_abundance
  FROM rrs_library_taxon_count
  JOIN rrs_library_spike_total
    USING (rrs_library_id, taxon_level)
  JOIN rrs_library_metadata
    USING (rrs_library_id)
;

