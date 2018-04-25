# ====================
#  Project Makefile
# ====================
#  Configuration {{{1
# GNU Make Configuration {{{2
# Set the shell to bash instead of `sh`.
SHELL := /bin/bash

# One failing step in a recipe causes the whole recipe to fail.
.POSIX:

# Don't delete intermediate files.
.SECONDARY:

# Delete targets if there is an error while executing a rule.
.DELETE_ON_ERROR:

# Warnings when variables are undefined (or empty?).
MAKEFLAGS += --warn-undefined-variables

# Don't use implicit rules.
MAKEFLAGS += --no-builtin-rules

.DEFAULT_GOAL := help

# User Help Message {{{2
HELP_TRGTS = help h HELP Help
.PHONY: ${HELP_TRGTS}
${HELP_TRGTS}:
	@echo "$$PROJECT_HELP_MSG" | less

define PROJECT_HELP_MSG

================================
 Analysis Makefile Documentation
================================

SYNOPSIS
    Run project operations using make commands.

TARGETS
    all
        Generate all. (By default this includes all figures,
        results, and documentation based on user-defined recipes.)

    docs
        Compile markdown files (e.g. NOTE.md, TEMPLATE.md) into HTML using
        Pandoc.

    figs
        Carry out the pipeline to ultimately generate figures of the results.

    res
        Carry out the pipeline to ultimately generate quantitative results files.

    help
        Show this help message.

    init
        Initialize the project
            (1) data-dirs
            (2) configure git to automatically clean IPython notebooks;

    python-reqs
        Install all python requirements from `requirements.pip` to the venv.

    data-dirs
        Create all data directories. Directories set in $${DATA_DIRS}.
        (${DATA_DIRS})

EXAMPLES
    make init  # Initialize the newly cloned project.
    make all   # Carry out all defined steps in the project.

See `man make` for help with GNU Make.


endef
export PROJECT_HELP_MSG

#  Convenience Targets {{{2
start-jupyter:
	jupyter notebook --config=nb/jupyter_notebook_config.py --notebook-dir=nb/

# Print the value of a given variable.
# Useful for debugging.
print-%:
	@echo '$*=${$*}'

#   Convenience Macros {{{2
LINK_TO_TARGET = ln -frs $< $@

# Pre-requisites: ${P<N>} where <N> is the pre-requisite index
P1  = $(word 1,$^)
P2  = $(word 2,$^)
P3  = $(word 3,$^)
P4  = $(word 4,$^)
P5  = $(word 5,$^)
P6  = $(word 6,$^)
P7  = $(word 7,$^)
P8  = $(word 8,$^)
P9  = $(word 9,$^)
P10 = $(word 10,$^)
P11 = $(word 11,$^)
P12 = $(word 12,$^)
P13 = $(word 13,$^)
P14 = $(word 14,$^)
P15 = $(word 15,$^)
P16 = $(word 16,$^)
P17 = $(word 17,$^)
P18 = $(word 18,$^)
P19 = $(word 19,$^)
P20 = $(word 20,$^)

CHECK_PREQS_EXIST = @[ -n "$^" ]
CHECK_N_PREQS_EQ = @[ "`echo $^ | wc -w`" -eq "$1" ]
CHECK_N_PREQS_GT = @[ "`echo $^ | wc -w`" -gt "$1" ]

# Prefix recipes which involve pipes to make sure we respect failures of
# non-terminal parts of the pipe.
PIPEFAIL := set -o pipefail;

#  Project Configuration {{{2

# Use this file to include sensitive data that shouldn't be version controlled.
# Others forking this project will need to create their own local.mk.
# If local.mk is vital and you would like the user to be alerted to its
# absence, remove the preceeding '-'.
-include local.mk

# Use this where you want a parameter for all cores to be used in a parallel
# computation.
MAX_PROCS ?= $(shell nproc)

# Phony targets {{{3
.PHONY: figs res
res: res/C2013.results.db seq/C2013.rrs.procd.clust.reps.afn
build: build/otu_details.xlsx
docs: build/paper_draft.docx
figs: fig/hplc.calibration.acetate.pdf \
      fig/hplc.calibration.butyrate.pdf \
      fig/hplc.calibration.glucose.pdf \
      fig/hplc.calibration.lactate.pdf \
      fig/hplc.calibration.propionate.pdf \
      fig/hplc.calibration.succinate.pdf

# What files are generated on `make all`?
all: docs figs res build

# Documentation targets {{{3
.PHONY: docs

BIB_FILE=doc/bibliography.bib

# Preqs for major documentation targets
build/README.%:

# Cleanup settings {{{3
# Use the following line to add files and directories to be deleted on `make clean`:
CLEANUP += *.log *.top *.plan *.logfile *.pbs.o* *.pbs.e* build/* *.temp.labels *.temp

.PHONY: clean
clean:
	rm -rf ${CLEANUP}

# Initialization settings {{{2
INIT_SEMAPHOR=.git/initialized
init: ${INIT_SEMAPHOR}

# Test if you're already initialized
INITIALIZED := $(shell [ -f ${INIT_SEMAPHOR} ] && echo True || echo False)

define NOT_INITIALIZED_MSG
This project is uninitialized.
To initialize run:
> make init

Ctrl-C to abort; any other key to continue.
endef

ifeq (${INITIALIZED},False)
    ifeq (${MAKELEVEL},0)
        $(warning ${NOT_INITIALIZED_MSG})
        $(shell read -r)
    endif
endif

${INIT_SEMAPHOR}:
	${MAKE}	data-dirs git-init
	touch $@


init: ${INIT_SEMAPHOR}

# What directories to generate on `make data-dirs`.
# By default, already includes build/ fig/
DATA_DIRS = build/ fig/ raw/ raw/ref raw/rrs ref/ res/ res/split seq/ seq/split

data-dirs:
	mkdir -p ${DATA_DIRS}

# Git Initialization {{{3
.PHONY: git-init .git-ipynb-filter-config .git-pager-config .git-daff-config

git-init: .git-ipynb-filter-config .git-pager-config .git-daff-config

.git-ipynb-filter-config:
	git config --local filter.dropoutput_ipynb.clean \
        scripts/ipynb_output_filter.py
	git config --local filter.dropoutput_ipynb.smudge cat

# Since Makefiles mix tabs and spaces, the default 8 spaces is too large
.git-pager-config:
	git config --local core.pager 'less -x4'

.git-daff-config:
	git config --local diff.daff-csv.command "daff.py diff --git"
	git config --local merge.daff-csv.name "daff.py tabular merge"
	git config --local merge.daff-csv.driver "daff.py merge --output %A %O %A %B"

# Software specific init {{{3
BOWTIE_FLAGS := --quiet
MEGAHIT_FLAGS :=

ifdef TMPDIR
$(info TMPDIR was set to ${TMPDIR}; may affect bowtie2, megahit)
${TMPDIR}/%: %
	@mkdir -p ${@D}
	cp $< $@

# Should bowtie2 use memory-mapped IO
BOWTIE_FLAGS += --mm
MEGAHIT_FLAGS += --tmp-dir ${TMPDIR}
else
TMPDIR ?= .
endif

# Software specific settings {{{2
# MOTHUR {{{3

# Link pre-requisites to the $BUILD dir
define MOTHUR_SETUP
# LINK PREQS: > $@
-ln -srt build/ $^
# START: > $@
endef

# Ordered list of pre-requisite link locations (in the $BUILD dir)
LN_PREQS = $(addprefix build/,$(notdir $^))

define MOTHUR_TEARDOWN
# FINISH: > $@
endef


#  Data Processing {{{1
# User defined recipes for cleaning up and initially parsing data.
# e.g. Slicing out columns, combining data sources, alignment, generating
# phylogenies, etc.

# 16S Community Analysis {{{2
# Dynamic Recipes {{{3
ifeq (${INITIALIZED},True)
    include build/rrs.mk
endif

build/rrs.mk: scripts/generate_rrs_makefile.py res/metadata.db
	$^ > $@

# raw/rrs/*.fastq.gz
# See scripts/generate_rrs_makefile.py
raw/rrs/%.rrs.r1.fastq.gz raw/rrs/%.rrs.r2.fastq.gz:
	fastq-dump --split-spot -Z ${SRA_ID} \
        | tee >(seqtk seq -1 | gzip > ${@D}/$*.rrs.r1.fastq.gz) \
              | seqtk seq -2 | gzip > ${@D}/$*.rrs.r2.fastq.gz

seq/split/%.rrs.r1.fastq.gz: raw/rrs/%.rrs.r1.fastq.gz
	${LINK_TO_TARGET}

seq/split/%.rrs.r2.fastq.gz: raw/rrs/%.rrs.r2.fastq.gz
	${LINK_TO_TARGET}

# Make fusions from paired-end reads
# Preqs defined in build/rrs.mk
# TODO: consider using rename=T
# TODO: Why does rename=T throw an error?
# ANSWER: Well, part of the reason is that we're renaming on a per-file basis.
seq/split/%.rrs.fuse.fn seq/split/%.rrs.fuse.qual res/split/%.rrs.fuse.report: \
        seq/split/%.rrs.r1.fastq.gz seq/split/%.rrs.r2.fastq.gz
	gzip -dc ${P1} > build/$*.rrs.r1.fastq
	gzip -dc ${P2} > build/$*.rrs.r2.fastq
	mothur "#make.contigs(ffastq=build/$*.rrs.r1.fastq, \
        rfastq=build/$*.rrs.r2.fastq, \
        trimoverlap=F, \
        rename=F)"
	@mv build/$*.rrs.r1.trim.contigs.fasta seq/split/$*.rrs.fuse.fn
	@mv build/$*.rrs.r1.trim.contigs.qual seq/split/$*.rrs.fuse.qual
	@mv build/$*.rrs.r1.contigs.report res/split/$*.rrs.fuse.report
	${MOTHUR_TEARDOWN}

# TODO: More efficient/universal .groups file generation
res/split/%.fuse.groups: scripts/get_groups.sh seq/split/%.fuse.fn
	$^ > $@

# Reference Sets {{{3

extract_from_tarball = tar -Oxzf ${1} ${2} > $@

raw/ref/Silva.nr_v119.tgz:
	wget --no-clobber --directory-prefix=${@D} http://www.mothur.org/w/images/2/27/Silva.nr_v119.tgz

raw/ref/Silva.nr_v128.tgz:
	wget --no-clobber --directory-prefix=${@D} https://www.mothur.org/w/images/b/b4/Silva.nr_v128.tgz

raw/ref/Silva.nr_v132.tgz:
	wget --no-clobber --directory-prefix=${@D} https://www.mothur.org/w/images/3/32/Silva.nr_v132.tgz

ref/silva.nr.afn: raw/ref/Silva.nr_v132.tgz
	$(call extract_from_tarball,$<,silva.nr_v132.align)

ref/silva.nr.tax: raw/ref/Silva.nr_v132.tgz
	$(call extract_from_tarball,$<,silva.nr_v132.tax)

%.pcr_v4.afn: %.afn
	@[ `seqtk seq -l 0 $< | head -2 | tail -1 | wc -c` -eq '50001' ]
	${MOTHUR_SETUP}
	mothur "#pcr.seqs(fasta=${LN_PREQS}, start=11894, end=25319, \
        keepdots=F, processors=${MAX_PROCS})"
	@mv build/$(notdir $*).pcr.afn $@
	${MOTHUR_TEARDOWN}

raw/ref/Silva.gold.bacteria.zip:
	wget --no-clobber --directory-prefix=${@D} http://www.mothur.org/w/images/f/f1/Silva.gold.bacteria.zip

ref/silva.gold.afn: raw/ref/Silva.gold.bacteria.zip
	unzip $<
	mv silva.gold.align $@
	@touch $@

raw/ref/Silva.seed_v119.tgz:
	wget --no-clobber --directory-prefix=${@D} http://www.mothur.org/w/images/1/15/Silva.seed_v123.tgz

raw/ref/Silva.seed_v128.tgz:
	wget --no-clobber --directory-prefix=${@D} https://www.mothur.org/w/images/a/a4/Silva.seed_v128.tgz

raw/ref/Silva.seed_v132.tgz:
	wget --no-clobber --directory-prefix=${@D} https://www.mothur.org/w/images/7/71/Silva.seed_v132.tgz

raw/ref/silva-ssu-128.arb.gz:
	curl https://www.arb-silva.de/fileadmin/arb_web_db/release_128/ARB_files/SSURef_NR99_128_SILVA_07_09_16_opt.arb.gz > $@

ref/silva-ssu-128.arb: raw/ref/silva-ssu-128.arb.gz
	zcat $< > $@


ref/silva.seed.afn: raw/ref/Silva.seed_v132.tgz
	$(call extract_from_tarball,$<,silva.seed_v132.align)

ref/silva.seed.tax: raw/ref/Silva.seed_v132.tgz
	$(call extract_from_tarball,$<,silva.seed_v132.tax)

raw/ref/Trainset14_032015.pds.tgz:
	wget --no-clobber --directory-prefix=${@D} http://www.mothur.org/w/images/8/88/Trainset14_032015.pds.tgz

ref/rdp.nr.fn: raw/ref/Trainset14_032015.pds.tgz
	$(call extract_from_tarball,$<,trainset14_032015.pds/trainset14_032015.pds.fasta)

ref/rdp.nr.tax: raw/ref/Trainset14_032015.pds.tgz
	$(call extract_from_tarball,$<,trainset14_032015.pds/trainset14_032015.pds.tax)

# Build BLAST databases
%.fn.nhr %.fn.nin %.fn.nsq: %.fn
	makeblastdb -dbtype nucl -parse_seqids -in $< -out $<

# Align, classify, screen and cluster seqs {{{3
# Screen 1: remove sequences which are the wrong length or have too many
# ambiguous nucleotides
# TODO: Screen params?
# TODO: Remove unused files from targets
seq/%.screen1.fn res/%.screen1.groups: seq/%.fn res/%.groups
	${MOTHUR_SETUP}
	mothur "#screen.seqs(fasta=$(word 1,${LN_PREQS}), group=$(word 2,${LN_PREQS}), \
        maxambig=0, maxlength=295, processors=${MAX_PROCS})"
	@mv build/$*.good.fn seq/$*.screen1.fn
	@mv build/$*.good.groups res/$*.screen1.groups
	${MOTHUR_TEARDOWN}

# Uniq-ify seqs {{{3
seq/%.uniq.fn res/%.uniq.names: seq/%.fn
	${MOTHUR_SETUP}
	mothur "#unique.seqs(fasta=${LN_PREQS})"
	@mv build/$*.unique.fn seq/$*.uniq.fn
	@mv build/$*.names res/$*.uniq.names
	${MOTHUR_TEARDOWN}

seq/%.uniq.afn res/%.uniq.names: seq/%.afn
	${MOTHUR_SETUP}
	mothur "#unique.seqs(fasta=${LN_PREQS})"
	@mv build/$*.unique.afn seq/$*.uniq.afn
	@mv build/$*.names res/$*.uniq.names
	${MOTHUR_TEARDOWN}

res/%.fuse.screen1.uniq.count_table: res/%.fuse.screen1.uniq.names res/%.fuse.screen1.groups
	${MOTHUR_SETUP}
	mothur "#count.seqs(name=$(word 1,${LN_PREQS}), \
        group=$(word 2,${LN_PREQS}), processors=${MAX_PROCS})"
	@mv build/$*.fuse.screen1.uniq.count_table res/$*.fuse.screen1.uniq.count_table
	${MOTHUR_TEARDOWN}

# Alignment {{{3
seq/%.align.afn res/%.align.report: seq/%.fn ref/silva.nr.pcr_v4.afn
	${MOTHUR_SETUP}
	mothur "#align.seqs(fasta=$(word 1,${LN_PREQS}), \
        reference=$(word 2,${LN_PREQS}), processors=${MAX_PROCS})"
	@mv build/$*.align seq/$*.align.afn
	@mv build/$*.align.report res/$*.align.report
	${MOTHUR_TEARDOWN}

# `unalign` is provided by sequtils python package.
%.fn: %.afn
	unalign < $< > $@

ref/silva.seed.fn: ref/silva.seed.afn
	unalign < $< | sed -r 's:>(\S+).*:>\1:' > $@

# Sequence cleanup and screening {{{3
seq/%.align.screen2.afn res/%.align.screen2.count_table: seq/%.align.afn res/%.count_table
	${MOTHUR_SETUP}
	mothur "#screen.seqs(fasta=$(word 1,${LN_PREQS}), start=3100, \
        count=$(word 2,${LN_PREQS}), end=10600, maxhomop=8, \
        processors=${MAX_PROCS})"
	@mv build/$*.align.good.afn seq/$*.align.screen2.afn
	@mv build/$*.good.count_table res/$*.align.screen2.count_table
	${MOTHUR_TEARDOWN}

seq/%.press.afn: seq/%.afn
	${MOTHUR_SETUP}
	mothur "#filter.seqs(fasta=$(word 1,${LN_PREQS}), vertical=T, trump=., \
        processors=${MAX_PROCS})"
	@mv build/$*.filter.fasta seq/$*.press.afn
	${MOTHUR_TEARDOWN}

seq/%.mask.afn: seq/%.afn
	${MOTHUR_SETUP}
	mothur "#filter.seqs(fasta=$(word 1,${LN_PREQS}), vertical=F, soft=25, processors=${MAX_PROCS})"
	@mv build/$*.filter.fasta seq/$*.mask.afn
	${MOTHUR_TEARDOWN}

seq/%.press.uniq.afn res/%.press.uniq.count_table: seq/%.press.afn res/%.count_table
	${MOTHUR_SETUP}
	mothur "#unique.seqs(fasta=$(word 1,${LN_PREQS}), \
        count=$(word 2,${LN_PREQS}))"
	@mv build/$*.press.unique.afn seq/$*.press.uniq.afn
	@mv build/$*.press.count_table res/$*.press.uniq.count_table
	${MOTHUR_TEARDOWN}

# TODO: Why doesn't the .name and .groups file combination work?
# I get told that there are names in the .names file which are not in the
# fasta, but those names are sub-names of uniq seqs, so that's what I expect...?
seq/%.preclust.afn res/%.preclust.count_table: \
    seq/%.afn \
    res/%.count_table
	${MOTHUR_SETUP}
	mothur "#pre.cluster(fasta=$(word 1,${LN_PREQS}), \
        count=$(word 2,${LN_PREQS}), diffs=3, \
        processors=${MAX_PROCS})"
	@mv build/$*.precluster.afn seq/$*.preclust.afn
	@mv build/$*.precluster.count_table res/$*.preclust.count_table
	${MOTHUR_TEARDOWN}

# Chimera screening {{{3
seq/%.screen3.afn res/%.screen3.chimeras res/%.screen3.count_table: seq/%.afn res/%.count_table
	${MOTHUR_SETUP}
	mothur "#chimera.uchime(fasta=$(word 1,${LN_PREQS}), \
        count=$(word 2,${LN_PREQS}), \
        dereplicate=T, processors=${MAX_PROCS})"
	@mv build/$*.denovo.uchime.chimeras res/$*.screen3.chimeras
	mothur "#remove.seqs(fasta=build/$*.afn, \
        accnos=build/$*.denovo.uchime.accnos)"
	@mv build/$*.pick.afn seq/$*.screen3.afn
	@mv build/$*.denovo.uchime.pick.count_table res/$*.screen3.count_table
	${MOTHUR_TEARDOWN}

# Taxonomic classification {{{3
res/%.tax: seq/%.afn ref/silva.nr.pcr_v4.fn ref/silva.nr.tax res/%.count_table
	${MOTHUR_SETUP}
	mothur "#classify.seqs(fasta=$(word 1,${LN_PREQS}), \
        count=$(word 4, ${LN_PREQS}), \
        reference=$(word 2,${LN_PREQS}), \
        taxonomy=$(word 3,${LN_PREQS}), \
        method=wang, cutoff=0, \
        processors=${MAX_PROCS})"
	@mv build/$*.nr.wang.taxonomy res/$*.tax
	${MOTHUR_TEARDOWN}

# Taxonomic screening {{{3
# Screen out Chloroplasts, Mitochondria, Archaea, Eukaryota
seq/%.screen4.afn res/%.screen4.tax res/%.screen4.count_table: seq/%.afn res/%.tax res/%.count_table
	${MOTHUR_SETUP}
	mothur "#remove.lineage(fasta=$(word 1,${LN_PREQS}), \
        count=$(word 3,${LN_PREQS}), \
        taxonomy=$(word 2,${LN_PREQS}), \
        taxon=Chloroplast-Mitochondria-Archaea-Eukaryota-Unknown)"
	@mv build/$*.pick.afn seq/$*.screen4.afn
	@mv build/$*.pick.tax res/$*.screen4.tax
	@mv build/$*.pick.count_table res/$*.screen4.count_table
	${MOTHUR_TEARDOWN}

# OTU tallying {{{3
# TODO: .names dependency instead of .count_table?
# This'll increase the size of the .otus file, but it will also mean it includes
# all of the names and not just the names associated with the counts.
# Maybe useful for representative sequence pulling?

OTU_CUTOFF ?= 0.03

res/%.clust.otus: seq/%.afn res/%.count_table res/%.tax
	${MOTHUR_SETUP}
	mothur "#cluster.split(fasta=$(word 1,${LN_PREQS}), \
       count=$(word 2,${LN_PREQS}), taxonomy=$(word 3,${LN_PREQS}), \
       splitmethod=classify, taxlevel=2, cutoff=${OTU_CUTOFF}, \
       processors=${MAX_PROCS}, method=opti)"
	@mv build/$*.opti_mcc.unique_list.list res/$*.clust.otus
	${MOTHUR_TEARDOWN}

res/%.names: scripts/otus_to_names_file.py res/%.otus
	${P1} ${OTU_CUTOFF} ${P2} > $@

# TODO: Test this???
res/%.clust.shared: res/%.clust.otus res/%.count_table
	${MOTHUR_SETUP}
	mothur "#make.shared(list=$(word 1,${LN_PREQS}), count=$(word 2,${LN_PREQS}), label=${OTU_CUTOFF})"
	@mv build/$*.clust.shared $@
	${MOTHUR_TEARDOWN}

res/%.clust.tax: res/%.clust.otus res/%.count_table res/%.tax
	${MOTHUR_SETUP}
	mothur "#classify.otu(list=$(word 1,${LN_PREQS}), count=$(word 2,${LN_PREQS}), \
        taxonomy=$(word 3,${LN_PREQS}), label=${OTU_CUTOFF})"
	@mv build/$*.clust.${OTU_CUTOFF}.cons.taxonomy $@
	${MOTHUR_TEARDOWN}

seq/%.clust.reps.afn: res/%.clust.otus \
    res/%.count_table seq/%.afn
	${MOTHUR_SETUP}
	mothur "#get.oturep(method=abundance, list=$(word 1,${LN_PREQS}), \
        count=$(word 2,${LN_PREQS}), fasta=$(word 3,${LN_PREQS}))"
	sed 's:>[^ ]\+\s\+\(Otu[0-9]\+\)|.*$$:>\1:' < build/$*.clust.${OTU_CUTOFF}.rep.fasta > $@
	${MOTHUR_TEARDOWN}

res/%.spike-blastn.tsv: seq/%.fn meta/rrs/spike.fn
	blastn -subject ${P2} -query ${P1} -max_target_seqs 1 -outfmt 6 | awk '$$3 > 98' > $@

res/%.spike-blastn.hits.tsv: res/%.spike-blastn.tsv
	printf 'taxon_id\ttaxon_level\tspike_seq_id\n' > $@
	awk -F '\t' -v OFS='\t' '{print $$1, "otu-${OTU_CUTOFF}", $$2}' $< >> $@

# Transform community matrix into a sparse form.
res/%.clust.read_count.tsv: scripts/stack_shared.py res/%.clust.shared
	$^ > $@

res/%.read_count.tsv: scripts/pivot_count_table.py res/%.count_table
	$^ > $@

res/%.clust.plus.read_count.tsv: scripts/concat_tables.py res/%.clust.read_count.tsv res/%.read_count.tsv
	$^ > $@

# Transform taxonomy tables (or names files) into a sparse form.
res/%.clust.tax.tsv: scripts/parse_otu_taxonomy.py res/%.clust.tax
	${P1} otu-${OTU_CUTOFF} < ${P2} > $@

res/%.clust.otu-map.tax.tsv: scripts/parse_names_as_taxonomy.py res/%.clust.names
	$^ unique otu-0.03 > $@

res/%.clust.plus.tax.tsv: scripts/concat_tables.py res/%.clust.tax.tsv res/%.clust.otu-map.tax.tsv
	$^ > $@

# Summarize status of sequences at various steps {{{3
res/%.summary: seq/%.afn res/%.count_table
	${MOTHUR_SETUP}
	mothur "#summary.seqs(fasta=$(word 1,${LN_PREQS}), count=$(word 2,${LN_PREQS}), processors=${MAX_PROCS})"
	@mv build/$*.summary $@
	${MOTHUR_TEARDOWN}

res/%.summary: seq/%.fn res/%.count_table
	${MOTHUR_SETUP}
	mothur "#summary.seqs(fasta=$(word 1,${LN_PREQS}), count=$(word 2,${LN_PREQS}), processors=${MAX_PROCS})"
	@mv build/$*.summary $@
	${MOTHUR_TEARDOWN}

res/%.align.summary: seq/%.align.afn res/%.count_table
	${MOTHUR_SETUP}
	mothur "#summary.seqs(fasta=$(word 1,${LN_PREQS}), count=$(word 2,${LN_PREQS}), processors=${MAX_PROCS})"
	@mv build/$*.align.summary $@
	${MOTHUR_TEARDOWN}

res/%.press.summary: seq/%.press.afn res/%.count_table
	${MOTHUR_SETUP}
	mothur "#summary.seqs(fasta=$(word 1,${LN_PREQS}), count=$(word 2,${LN_PREQS}), processors=${MAX_PROCS})"
	@mv build/$*.press.summary $@
	${MOTHUR_TEARDOWN}

res/%.summary: seq/%.fn
	${MOTHUR_SETUP}
	mothur "#summary.seqs(fasta=$(word 1,${LN_PREQS}), processors=${MAX_PROCS})"
	@mv build/$*.summary $@
	${MOTHUR_TEARDOWN}

res/%.length.tsv: seq/%.afn
	unalign $< | seqtk seq -l 0 \
        | awk 'NR%2==1 {print $$0} NR%2==0 {print length($$0)}' \
        | sed 's:^>::' | paste - - \
        > $@

res/%.length.dist.tsv: res/%.length.tsv
	cut -f2 $< \
        | sort | uniq -c \
        | awk -v OFS='\t' '{print $$2, $$1}' \
        > $@

# Rename finished files {{{3
RRS_PROCD_INFIX := fuse.screen1.uniq.align.screen2.press.uniq.screen3.screen4

seq/%.rrs.procd.afn: seq/%.rrs.${RRS_PROCD_INFIX}.afn
	${LINK_TO_TARGET}
res/%.rrs.procd.count_table: res/%.rrs.${RRS_PROCD_INFIX}.count_table
	${LINK_TO_TARGET}
res/%.rrs.procd.tax: res/%.rrs.${RRS_PROCD_INFIX}.tax
	${LINK_TO_TARGET}
res/%.rrs.procd.clust.names: res/%.rrs.${RRS_PROCD_INFIX}.clust.names
	${LINK_TO_TARGET}
res/%.rrs.procd.clust.shared: res/%.rrs.${RRS_PROCD_INFIX}.clust.shared
	${LINK_TO_TARGET}
res/%.rrs.procd.clust.tax: res/%.rrs.${RRS_PROCD_INFIX}.clust.tax
	${LINK_TO_TARGET}
seq/%.rrs.procd.clust.reps.afn: seq/%.rrs.${RRS_PROCD_INFIX}.clust.reps.afn
	${LINK_TO_TARGET}

# 16S Sequence Analysis {{{2
# Alignment {{{3
seq/%.sina.afn: seq/%.fn ref/silva-ssu-128.arb
	sina --in ${P1} --intype fasta \
        --ptdb ${P2} --turn all \
        --overhang remove --lowercase unaligned --insertion shift \
        --out $@ --outtype fasta \
        --line-length 0 \
        --log build/${@F}.log

ref/%.sina.afn: ref/%.fn ref/silva-ssu-128.arb
	sina --in ${P1} --intype fasta \
        --ptdb ${P2} --turn all \
        --overhang remove --lowercase unaligned --insertion shift \
        --out $@ --outtype fasta \
        --line-length 0 \
        --log build/${@F}.log

# Bacteroidales phylogeny with OTU-1 and OTU-4 {{{3

# Fetch refs
ref/silva.nr.name-link: ref/silva.nr.afn
	grep '^>' $<  \
		| sed -e 's:^>::' -e 's:;:|:g' \
        | awk -v OFS='	' '{print $$1, $$3 "|" $$1}' \
        | sed -e 's:[^A-Za-z0-9_.|\t]:_:g' \
        > $@

ref/bacteroidales_ref.silva.list: ref/silva.nr.name-link \
        meta/misc/bacteroidales_ref.silva.pattern.list \
        meta/misc/bacteroidales_ref.silva.antipattern.list
	grep -f ${P2} ${P1} | grep --invert-match -f ${P3} | awk '$$2>99' | cut -f1 > $@

ref/bacteroidales_ref.silva.rename.afn: ref/silva.nr.afn \
        ref/bacteroidales_ref.silva.list \
        ref/silva.nr.name-link
	seqtk subseq ${P1} ${P2} | rename_seqs ${P3} | seqtk seq -l0 > $@

ref/custom_ref_seqs.fn: meta/misc/custom_ref_seqs.fn
	ln -fsrt ref $<

seq/s247_of_interest.afn: seq/C2013.rrs.procd.clust.reps.afn
	seqtk subseq ${P1} <(printf 'Otu0001\nOtu0004') > $@

seq/s247_of_interest.wrefs.afn: \
        ref/bacteroidales_ref.silva.rename.pcr_v4.afn \
        ref/custom_ref_seqs.sina.pcr_v4.afn \
        seq/s247_of_interest.sina.pcr_v4.afn
	cat $^ > $@

seq/s247_of_interest.%.realign.afn: seq/s247_of_interest.%.afn
	muscle -refine -in $< -out $@

seq/%.mask2.afn: seq/%.afn
	${MOTHUR_SETUP}
	mothur "#filter.seqs(fasta=$(word 1,${LN_PREQS}), vertical=F, soft=40, processors=${MAX_PROCS})"
	@mv build/$*.filter.fasta $@
	${MOTHUR_TEARDOWN}

res/s247_of_interest.%.nwk: seq/s247_of_interest.%.afn
	FastTree -nt -gtr -gamma < $< > $@


# HPLC {{{2

# Raw data {{{3
# FIXME: Don't hardcode These filenames in the makefile.
HPLC_LCS_EXPORTS = \
    2015-12-19.RI \
    2015-12-20.RI \
    2015-12-30_a.RI \
    2016-01-08_b.RI \
    2016-01-08_c.RI \
    2016-01-24.RI \
    2016-01-26.RI \
    2016-02-26_a.RI \
    2016-02-26_b.RI \
    2016-03-10.RI \
    2016-05-08.RI \
    2016-05-11.RI \
    2016-05-15.RI \
    2016-05-18.RI \
    2016-06-28.RI

# Clean up lcs_export files which are malformed {{{3


res/split/%.lcs_export.txt: raw/hplc/%.lcs_export.txt
	ln -fsr $< $@

res/split/2016-01-08_b.%.lcs_export.txt: raw/hplc/proto/2016-01-08_b.%.lcs_export.txt
	sed '/2016-01-08_00[0-8]\.lcd/d' < $< > $@

res/split/2016-05-11.%.lcs_export.txt: raw/hplc/proto/2016-05-11.%.lcs_export.txt
	sed '/2016-05-08_001\.lcd/d' < $< > $@

res/split/2016-03-02.RI.lcs_export.txt: raw/hplc/proto/2016-03-02.RI.lcs_export.txt
	sed 's:sialic acid:sialic_acid:' < $< > $@

res/split/2016-03-10.RI.lcs_export.txt: raw/hplc/proto/2016-03-10.RI.lcs_export.txt
	sed 's:sialic acid:sialic_acid:' < $< > $@

res/split/2016-01-26.RI.lcs_export.txt: raw/hplc/proto/2016-01-26.RI.lcs_export.txt
	sed 's:sialic acid:sialic_acid:' < $< > $@

# Process raw data to TSV {{{3
res/split/%.hplc.peak.tsv: scripts/parse_lcs_export.py res/split/%.lcs_export.txt
	$^ --constant channel=$(subst .,,$(suffix $*)) > $@

HPLC_PEAK_SPLITS := $(patsubst %,res/split/%.hplc.peak.tsv,${HPLC_LCS_EXPORTS})
res/hplc.peak.tsv: scripts/concat_tables.py ${HPLC_PEAK_SPLITS}
	$^ > $@

# Calibration {{{3

res/hplc.calibration.tsv: \
        scripts/calibrate_hplc.py res/metadata.db res/hplc.peak.tsv
	$^ > $@

# QC {{{3

res/%.peak.qc.tsv: scripts/qc_hplc.py res/%.peak.tsv meta/hplc/molecule.tsv
	$^ > $@

fig/hplc.calibration.%.pdf: scripts/plot_hplc_calibration.py res/C2013.results.db
	$^ --subset molecule_id=$* --outfile $@

# Database {{{2

res/metadata.sql: scripts/import_db.py schema_metadata.sql \
        meta/mouse.tsv meta/sample.tsv meta/extraction.tsv meta/hplc/molecule.tsv \
        meta/hplc/standard.tsv meta/hplc/known.tsv meta/hplc/injection.tsv \
        meta/hplc/calibration_group.tsv meta/hplc/calibration_config.tsv \
        meta/rrs/primer.tsv meta/spike.tsv \
        meta/rrs/library.tsv meta/rrs/analysis_group.tsv
	${P1} --schema ${P2} \
        -t mouse=${P3} \
        -t sample=${P4} \
        -t extraction=${P5} \
        -t molecule=${P6} \
        -t standard=${P7} \
        -t known=${P8} \
        -t injection=${P9} \
        -t calibration_group=${P10} \
        -t calibration_config=${P11} \
        -t primer=${P12} \
        -t spike=${P13} \
        -t rrs_library=${P14} \
        -t rrs_analysis_group=${P15} \
        --dump-sql > $@

res/C2013.results.sql: \
        scripts/import_db.py \
        res/metadata.sql \
        schema_results.sql \
        res/hplc.peak.tsv \
        res/hplc.peak.qc.tsv \
        res/hplc.calibration.tsv \
        res/C2013.rrs.procd.clust.plus.read_count.tsv \
        res/C2013.rrs.procd.clust.plus.tax.tsv \
        res/C2013.rrs.procd.clust.reps.spike-blastn.hits.tsv
	${P1} --sql ${P2} --schema ${P3} \
        -t peak=${P4} \
        -t peak_qc=${P5} \
        -t calibration=${P6} \
        -t _rrs_library_taxon_count=${P7} \
        -t taxonomy=${P8} \
        -t rrs_spike_strain_hit=${P9} \
        --dump-sql > $@

SQLITE_CACHE_MEMORY := 1000000

%.db: %.sql
	@rm -f $@
	cat <(echo "PRAGMA cache_size = ${SQLITE_CACHE_MEMORY};") \
        $< \
        <(echo "PRAGMA foreign_key_check;") \
        <(echo "ANALYZE;") \
        | pv | sqlite3 ${TMPDIR}/${@F}.temp
	mv ${TMPDIR}/${@F}.temp $@

# Simple Transformations {{{2

seq/split/%.fastq: seq/split/%.fastq.gz
	zcat $< > $@

%.fn: %.fastq.gz
	seqtk seq -A $< > $@

%.fn: %.fastq
	seqtk seq -A $< > $@

%.sqz.afn: scripts/squeeze_alignment.py %.afn
	${P1} '-.acgtu' < ${P2} > $@

seq/%.tree-sort.afn: scripts/get_ordered_leaves.py res/%.nwk seq/%.afn
	fetch_seqs --match-order <(${P1} ${P2}) ${P3} > $@

ref/%.tree-sort.afn: scripts/get_ordered_leaves.py res/%.nwk ref/%.afn
	fetch_seqs --match-order <(${P1} ${P2}) ${P3} > $@

# Estimate Phylogenies {{{2
res/%.nwk: seq/%.afn
	FastTree -nt < $< > $@

res/%.nwk: ref/%.afn
	FastTree -nt < $< > $@

%.nwk: %.afn
	FastTree -nt < $< > $@

RAXML_OPTIONS = -x 1 -p 1 -\\\# 10 -f a -m GTRGAMMA
RAXML ?= raxmlHPC-PTHREADS-SSE3 -T ${MAX_PROCS}

res/%.raxml.nwk: seq/%.afn
	${RAXML} ${RAXML_OPTIONS} -s $< -w $$PWD/build -n $(notdir $@)
	@mv build/RAxML_bipartitions.$(notdir $@) $@
	@for file in build/RAxML_*.$(notdir $@); do mv $$file $$file~; done

# Documents {{{1
# Jupyter Notebooks {{{2
build/%.ipynb: nb/%.ipynb
	jupyter nbconvert $< \
        --config=nb/jupyter_notebook_config.py \
        --to notebook --execute --ExecutePreprocessor.timeout=600 \
        --stdout > $@
# Add pre-requisites for particular jupyter notebooks so that
# `make build/<notebook>.ipynb` will first make those pre-reqs.
# e.g.
# build/notebook.ipynb: res/results.tsv

# Extra requirements for notebooks
build/2018-03-19_s247_tree.ipynb: \
        res/s247_of_interest.wrefs.press.realign.mask.uniq.nwk \
        meta/misc/bacteroidales_family_designation.tsv

build/2018-03-13_bayesian_survival_path_analysis.ipynb: res/C2013.results.db
build/2018-03-14_survival_analysis-supplement.ipynb: res/C2013.results.db
build/2018-03-16_paper_results.ipynb: res/C2013.results.db
build/2018-03-21_otu_details_supplemental.ipynb: res/C2013.results.db
build/2018-03-21_s247_phylotypes.ipynb: res/C2013.results.db

# Figure building for doc/paper_draft.*
fig/comm_pcoa.png fig/comm_pcoa.pdf: build/2018-03-16_paper_results.ipynb
fig/dominant_otus_box.png fig/dominant_otus_box.pdf: build/2018-03-16_paper_results.ipynb
fig/scfa_box.png fig/scfa_box.pdf: build/2018-03-16_paper_results.ipynb
fig/metab_corr.png fig/metab_corr.pdf: build/2018-03-16_paper_results.ipynb
# This figure can't be made without the full data:
# fig/survival_sample.png fig/survival_sample.pdf: build/2018-03-16_paper_results.ipynb

# Supplemental figures and tables
fig/s247_tree.png fig/s247_tree.pdf: build/2018-03-19_s247_tree.ipynb
fig/s247_phylotypes.png fig/s247_phylotypes.pdf: build/2018-03-21_s247_phylotypes.ipynb
fig/scfa_box_supplement.png fig/scfa_box_supplement.pdf: build/2018-03-16_paper_results.ipynb
fig/otu_details.xlsx: build/2018-03-21_otu_details.supplemental.ipynb
fig/phreg_residuals.png fig/survival_predict.png fig/phreg_residuals.pdf fig/survival_predict.pdf: build/2018-03-14_survival_analysis-supplement.ipynb

# Generic Recipes {{{2

fig/%.pdf: doc/static/%.svg
	svg2pdf $< $@

fig/acarbose_structure.pdf: doc/static/acarbose_structure.svg
	svg2pdf -h 50 $< $@


build/%.html: doc/%.md ${BIB_FILE}
	pandoc --from markdown --to html5 \
        --filter pandoc-crossref --highlight-style pygments \
        --standalone --self-contained --mathjax=${MATHJAX} \
        --table-of-contents --toc-depth=4 \
        --css doc/static/main.css --bibliography=${P2} \
        -s ${P1} -o $@

build/%.docx: doc/%.md ${BIB_FILE} doc/static/example_style.docx
	pandoc --from markdown --to docx \
        --filter pandoc-crossref --highlight-style pygments \
        --bibliography=${BIB_FILE} \
        --reference-doc=${P3} \
        -o $@ ${P1}

build/%.tex: doc/%.md ${BIB_FILE} doc/latex.template
	pandoc --from markdown --to latex \
        --filter pandoc-crossref --highlight-style pygments \
        --standalone --template ${P3} \
        --natbib --bibliography ${BIB_FILE} \
        --wrap=preserve -t latex \
        -o $@ ${P1}

build/%.pdf: doc/%.tex ${BIB_FILE}
	latexmk -lualatex -outdir=${@D} -auxdir=${@D} -bibtex $<

build/%.pdf: build/%.tex ${BIB_FILE}
	latexmk -lualatex -outdir=${@D} -auxdir=${@D} -bibtex $<

# Manuscripts {{{2
build/%.png2pdf.tex: build/%.tex
	sed -e 's:\.png:.pdf:' \
        -e 's:α:$$\\alpha$$:g' \
        -e 's:μ\([A-Za-z0-9]*\):$$\\mu$${\1}:g' \
        -e 's:β:$$\\beta$$:g' \
        -e 's:ρ:$$\\rho$$:g' \
        < $^ > $@

preprint_figure_basenames := \
        survival_sample \
        comm_pcoa \
        dominant_otus_box \
        scfa_box \
        metab_corr \
        scfa_box_supplement \
        s247_tree \
        s247_phylotypes \
        phreg_residuals \
        survival_predict

build/preprint.png2pdf.pdf: \
        $(patsubst %,fig/%.pdf,${preprint_figure_basenames})

build/preprint.html build/preprint.docx build/preprint.pdf: \
        $(patsubst %,fig/%.png,${preprint_figure_basenames})
