# Data setup

The completed study used the user-supplied two-date extracts
`41_foolsday.xlsx` and `58mothersday data.xlsx`. The raw workbooks are not
redistributed in this repository. Obtain the original public exports from
[Furberg et al., Zenodo](https://zenodo.org/records/53894) and review the
source's terms before using or redistributing data. This project analyzes
April 1 and May 8, 2016, rather than the full multiday archive.

For an exact rerun, place the two study extracts in `data/raw/` using the filenames
in `config.yml`. Raw data are ignored by Git. The original author retains the
completed local input files; reproducing the exact numeric study requires those
extracts or equivalent tables with identical participant membership, values,
and row order. The bundled aggregate results and report can be explored without
the raw inputs.

The input columns, in order, are:

```text
Participant, Id, Date, Weekend, Hour00, Hour01, ..., Hour23
```

April's file has a header; May's file has **no header**. Each row is one
participant, with source ID, date, weekend indicator (0/1), and 24 hourly step
counts. The loader handles both workbook layouts explicitly. Dates can be Excel
dates or ISO date strings. Never replace legitimate zeros with missing values.

If creating new extracts from the public archive, document the selection and
row order. A new row order changes which participant/hour entries a seeded mask
selects, even when all observed counts are unchanged. New extracts are a new
experiment unless exact equivalence to the study inputs has been verified.

The included `results/descriptive/participant_counts.csv` supplies only aggregate
cohort counts for the report. No participant linkage table or source-ID mapping
is distributed. A full local rerun creates its own participant linkage file under
`data/processed/` and updates the aggregate counts. Processed participant files
are ignored by Git. Review generated artifacts before sharing a rerun, as fresh
local outputs retain input IDs.
