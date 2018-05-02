[![DOI](https://zenodo.org/badge/130877028.svg)](https://zenodo.org/badge/latestdoi/130877028)

# Summary

This repository contains
code and metadata to reproduce results in "Changes in the gut microbiota and
fermentation products associated with enhanced longevity in acarbose-treated
mice".

# Quickstart

These instructions are for an ideal world.
They will probably not work for you;
it's worth a shot though, right?

1.  Install all required software (see Requirements).
    This is most likely accomplished using a combination of your system's
    package manager, conda, pip, and R's `install.packages()`.
2.  Clone this repo.
3.  Make necessary directories (among other setup) using `make init`.
4.  Check out the plan: `make -n build/preprint.pdf build/otu_details.xlsx | less`.
5.  Run the pipeline: `make build/preprint.pdf build/otu_details.xlsx`.
    You may want to adjust some of Make's options, e.g. `-j 12 --keep-going MAX_PROCS=12`

Errors when using these instructions probably indicate that software hasn't
been installed correctly.

# Requirements

-   Python
    -   See `requirements.pip`
-   R
    -   vegan (2.4-6)
    -   survminer (0.4.2)
    -   DESeq2 (1.18.1)
    -   survival (2.41-3)
-   MOTHUR (1.39.4)
-   FastTree (2.1.10)
-   MUSCLE (3.8.1551)
-   ncbi-blast (2.7.1)
-   sra-tools (2.8.2)
-   SQLite3 (3.19.3)
-   GNU Make (4.2.1)
-   LaTeX (3.14159265-2.6-1.40.18)
-   Latexmk (4.52c)
-   curl
-   wget
-   git (2.7.2)

# Abstract

##### Background
Treatment with the &alpha;-glucosidase inhibitor acarbose increases
median lifespan by approximately 20% in male mice and 5% in females.
This longevity extension differs from dietary restriction based on a
number of features, including the relatively small effects on weight
and the sex-specificity of the lifespan effect.
By inhibiting host digestion, acarbose increases the flux of starch to the
lower digestive system, resulting in changes to the gut
microbiota and their fermentation products.
Given the documented health benefits of short-chain fatty acids (SCFAs),
the dominant products of starch fermentation by gut bacteria, this secondary
effect of acarbose could contribute to increased longevity in mice.
To explore this hypothesis, we compared the fecal microbiome of mice treated
with acarbose to control mice at three independent study sites.

##### Results
Microbial communities and the concentrations of SCFAs in the feces of mice
treated with acarbose were notably different from those of control mice.
At all three study sites, the bloom of a single bacterial taxon
was the most obvious response to acarbose treatment.
The blooming populations were classified to the largely uncultured
_Bacteroidales_ family _Muribaculaceae_ and were the same taxonomic unit at two
of the three sites.
Total SCFA concentrations in feces were increased in treated mice, with
increased butyrate and propionate in particular.
Across all samples, _Muribaculaceae_ abundance was strongly correlated with
propionate and community composition was an important predictor
of SCFA concentrations.
Cox proportional hazards regression showed that the fecal concentrations of
acetate, butyrate, and propionate were, together, predictive of mouse longevity
even while controlling for sex, site, and acarbose.

##### Conclusion
We have demonstrated a correlation between fecal SCFAs and lifespan in mice,
suggesting a role of the gut microbiota in the longevity-enhancing properties
of acarbose.
Treatment modulated the taxonomic composition and fermentation products of the
gut microbiome, while the site-dependence of the microbiota illustrates the
challenges facing reproducibility and interpretation in microbiome studies.
These results motivate future studies exploring manipulation of the gut
microbial community and its fermentation products for increased longevity,
and to test a causal role of SCFAs in the observed effects of acarbose.
