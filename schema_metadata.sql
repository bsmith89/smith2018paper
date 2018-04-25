/*
 * Project: longev
 * Syntax: SQLite3
 * 
 * Tables and views which are loaded with raw and processed data.
 *
 */

-- Pragmas {{{1
PRAGMA foreign_keys = ON;

-- Tables {{{1
-- general metadata {{{2
CREATE TABLE mouse
  ( mouse_id            TEXT PRIMARY KEY
  , cohort              TEXT
  , sex                 TEXT
  , treatment           TEXT       -- {acarbose, inulin, control, young (control),
                                   -- + cr (calorie-restricted), (17-alpha-)estradiol
                                   -- + rapamycin}
  , site                TEXT       -- {JL (Jackson Labs), UM (University of Michigan),
                                   -- + UT (University of Texas, San Antonio)}
  , cage_id                TEXT
  , date_of_birth       DATETIME
  , age_at_death_or_censor  INTEGER    -- in days
  , censored                BOOLEAN
  );

CREATE TABLE sample
  ( sample_id                   TEXT PRIMARY KEY
  , mouse_id             TEXT REFERENCES mouse(mouse_id)
  , collection_date      DATETIME
  , collection_time      DATETIME    -- Hour out of 24 local time
  , empty_tube_weight    FLOAT       -- in g
  , full_tube_weight     FLOAT       -- in g
  , hydrated_tube_weight FLOAT       -- in g of the sample after
                                     -- + homogenizing in water, spinning, and
                                     -- + pulling off the accessible supernatant
  , comments             TEXT
  );

CREATE TABLE spike
  ( spike_id          TEXT
  , spike_seq_id   TEXT NOT NULL   -- strain name
  , rrs_copies        TEXT NOT NULL   -- number of copies of each strain's rrs per uL

  , PRIMARY KEY (spike_id, spike_seq_id)
  );


CREATE TABLE extraction
  ( extraction_id                      TEXT PRIMARY KEY
  , sample_id               TEXT REFERENCES sample(sample_id)
  , weight                  FLOAT    -- of the sample extracted from in g
  , hydrated_weight         FLOAT    -- in g of the sample after
                                     -- + homogenizing in water, spinning, and
                                     -- + pulling off the accessible supernatant
  , volume                  FLOAT    -- in mL of water used to extract the sample
  , spike_id        TEXT             -- FIXME: This needs to be constrained to
                                     -- + values in spike(spike_id)
  , spike_volume    FLOAT            -- in uL
  , dna_concentration  FLOAT   -- ng/ul
  , comments                TEXT
  );

-- hplc {{{2
CREATE TABLE molecule
  ( molecule_id                    TEXT PRIMARY KEY
  , retention_constant    FLOAT
  , uv_viz_ri_ratio       FLOAT
  );


CREATE TABLE standard
  ( standard_id          TEXT
  , molecule_id             TEXT REFERENCES molecule(molecule_id)
  , concentration FLOAT              -- Concentration of this molecule in the
                                     -- + stock solution

  , PRIMARY KEY (standard_id, molecule_id)
  );

CREATE TABLE known
  ( known_id          TEXT PRIMARY KEY
  -- FIXME: standard_id should be referencing a list of standards which
  -- standard_conc also references.  e.g.:
  -- , standard_id TEXT REFERENCES standard(standard_id)
  , standard_id TEXT                -- FIXME: This needs to be constrained to
                                    -- + standard(standard_id)
  , dilution    FLOAT               -- Relative to the stock solution
  );

CREATE TABLE injection
  ( injection_id             TEXT PRIMARY KEY
  , extraction_id  TEXT REFERENCES extraction(extraction_id)  -- Null if a standard/blank/etc.
  , known_id       TEXT REFERENCES known(known_id)       -- Null if an unknown sample
  , volume         FLOAT NOT NULL                  -- of the injection in uL
  , fraction_known FLOAT NOT NULL                  -- 0 or 1 unless sample is spiked
  );

CREATE TABLE calibration_group
  ( injection_id      TEXT REFERENCES injection(injection_id)
  , calibration_group TEXT

  , PRIMARY KEY (injection_id, calibration_group)
  );

CREATE TABLE calibration_config
  ( molecule_id               TEXT REFERENCES molecule(molecule_id)
  , channel                TEXT NOT NULL
  , intercept             BOOLEAN NOT NULL CHECK (intercept IN (0, 1))

  , PRIMARY KEY (molecule_id, channel)
  );

-- rrs {{{2
CREATE TABLE primer
  ( primer_id              TEXT PRIMARY KEY
  , sequence        TEXT NOT NULL
  );

CREATE TABLE rrs_library
  ( rrs_library_id              TEXT PRIMARY KEY
  , extraction_id   TEXT REFERENCES extraction(extraction_id)
  , run             TEXT             -- Unique ID for the PCR/sequencing run
  , primer_f        TEXT REFERENCES primer(primer_id)
  , primer_r        TEXT REFERENCES primer(primer_id)
  , sra_id          TEXT             -- ID for use with fastq-dump (sra-tools)
  );

CREATE TABLE rrs_analysis_group
  ( rrs_library_id      TEXT REFERENCES rrs_library(rrs_library_id)
  , analysis_group  TEXT NOT NULL

  , PRIMARY KEY (rrs_library_id, analysis_group)
  );

-- Views {{{1
-- general {{{2

--  For consistency with other *_metadata tables.
CREATE VIEW mouse_metadata AS
  SELECT * FROM mouse
;

CREATE VIEW sample_metadata AS
  SELECT
    sample_id
  , mouse_id
  , collection_date
  , collection_time
  , full_tube_weight - empty_tube_weight AS weight
  , hydrated_tube_weight - empty_tube_weight AS hydrated_weight
  , (full_tube_weight - empty_tube_weight) /
      (hydrated_tube_weight - empty_tube_weight)
      AS hydration_factor
  , sample.comments AS comments
  , cohort
  , sex
  , treatment
  , site
  , cage_id
  , date_of_birth
  , JULIANDAY(collection_date) - JULIANDAY(date_of_birth) AS age_at_collect
  , age_at_death_or_censor
  , censored
  FROM sample
  LEFT JOIN mouse
    USING (mouse_id)
;

CREATE VIEW extraction_weight AS
  SELECT
    extraction_id
  , CASE WHEN extraction.weight IS NOT NULL
      THEN extraction.weight
      ELSE sample.weight
    END AS weight
  , CASE WHEN extraction.hydrated_weight IS NOT NULL
      THEN extraction.hydrated_weight
      ELSE sample.hydrated_weight
    END AS hydrated_weight
  FROM extraction
  LEFT JOIN sample_metadata AS sample
    USING (sample_id)
;

CREATE VIEW extraction_metadata AS
  SELECT
    extraction_id
  , sample_id
  , weight.weight AS weight
  , weight.hydrated_weight AS hydrated_weight
  , sample.weight AS sample_weight
  , weight.weight / weight.hydrated_weight AS hydration_factor
  , volume
  , spike_id
  , spike_volume
  , dna_concentration
  , extraction.comments
  , mouse_id
  , collection_date
  , collection_time
  , sample.comments AS sample_comments
  , cohort
  , sex
  , treatment
  , site
  , cage_id
  , date_of_birth
  , age_at_collect
  , age_at_death_or_censor
  , censored
  FROM extraction
  LEFT JOIN sample_metadata AS sample
    USING (sample_id)
  LEFT JOIN extraction_weight AS weight
    USING (extraction_id)
;

CREATE VIEW known_metadata AS
  SELECT
    known_id
  , molecule_id
  , standard_id
  , standard.concentration * known.dilution AS known_concentration
  FROM known
  LEFT JOIN standard
    USING (standard_id)
;

-- hplc {{{2

CREATE VIEW unknown_injection AS
  SELECT * FROM injection
  WHERE fraction_known = 0.0
;

CREATE VIEW known_injection AS
  SELECT * FROM injection
  WHERE fraction_known = 1.0
;

CREATE VIEW spike_injection AS
  SELECT * FROM injection
  WHERE fraction_known > 0.0
    AND fraction_known < 1.0
;


CREATE VIEW unknown_injection_metadata AS
  SELECT
    injection_id
  , extraction_id
  , injection.volume
  , sample_id
  , extraction_metadata.weight AS extraction_weight
  , extraction_metadata.hydrated_weight AS extraction_hydrated_weight
  , sample_weight
  , extraction_metadata.volume AS extraction_volume
  , extraction_metadata.comments AS extraction_comments
  , mouse_id
  , collection_date
  , collection_time
  , sample_comments
  , cohort
  , sex
  , treatment
  , site
  , cage_id
  , date_of_birth
  , age_at_collect
  , age_at_death_or_censor
  , censored
  FROM injection
  INNER JOIN extraction_metadata
    USING (extraction_id)

  WHERE fraction_known = 0.0
;

CREATE VIEW known_injection_metadata AS
  SELECT
    injection_id
  , molecule_id
  , known_concentration
  , known_id
  , volume
  , standard_id
  FROM injection
  INNER JOIN known_metadata
    USING (known_id)

  WHERE fraction_known = 1.0
;

CREATE VIEW spike_injection_metadata AS
  SELECT
    injection_id
  , extraction_id
  , known_id
  , fraction_known
  , injection.volume
  , sample_id
  , standard_id
  , known_metadata.known_concentration * injection.fraction_known AS known_spike_concentration
  , extraction_metadata.weight AS extraction_weight
  , extraction_metadata.hydrated_weight AS extraction_hydrated_weight
  , sample_weight
  , extraction_metadata.volume AS extraction_volume
  , extraction_metadata.comments AS extraction_comments
  , mouse_id
  , collection_date
  , collection_time
  , sample_comments
  , cohort
  , sex
  , treatment
  , site
  , cage_id
  , date_of_birth
  , age_at_collect
  , age_at_death_or_censor
  , censored
  FROM injection
  LEFT JOIN extraction_metadata
    USING (extraction_id)
  LEFT JOIN known_metadata
    USING (known_id)

  WHERE fraction_known != 0.0
    AND fraction_known != 1.0
;

-- rrs {{{2
CREATE VIEW rrs_library_metadata AS
  SELECT
    rrs_library_id
  , extraction_id
  , run
  , sra_id
  , sample_id
  , extraction.weight AS extraction_weight
  , extraction.hydrated_weight AS extraction_hydrated_weight
  , sample_weight
  , extraction.volume AS extraction_volume
  , spike_id
  , spike_volume
  , extraction.comments AS extraction_comments
  , mouse_id
  , collection_date
  , collection_time
  , sample_comments
  , cohort
  , sex
  , treatment
  , site
  , cage_id
  , date_of_birth
  , age_at_collect
  , age_at_death_or_censor
  , censored
  FROM rrs_library
  LEFT JOIN extraction_metadata AS extraction
    USING (extraction_id)
;

