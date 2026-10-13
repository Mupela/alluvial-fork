# alluvial (fork with extra label options)

A small fork of **[`alluvial`](https://github.com/asjadnaqvi/stata-alluvial)** by
Asjad Naqvi (v1.5), a Stata command for drawing alluvial / Sankey-style flow
plots. This fork adds a few opt-in options and changes nothing else — any
existing `alluvial` call behaves exactly as before unless you pass the new
options. See `help alluvial` for `sortsize()`, `mergeflows()` and `flowsort()`.

## Why

When flows are shown as a percentage of the whole sample (`percent2`),
late-stage flows are often well under 1%. The stock command rounds them with a
single `format()`, so sub-1% flows print as `0` and, where several thin flows
converge on one narrow node, their value labels stack on top of each other.

## New options

| Option | What it does |
|---|---|
| `valdec1` | Formats labels as a **whole number when the value is ≥1** and with **one decimal when <1** — for both flow values and the category percentages. So `98`, `68`, `2` stay whole while `0.5`, `0.2` keep a decimal. Overrides `format()` for the labels. |
| `valnudge(#)` | Pushes apart value labels that would otherwise **overlay each other** where thin flows meet at a narrow node. `#` is the minimum vertical gap between labels in plot y-units (larger = more separation). The flows are unchanged — only the label anchor moves. `valnudge(0)` = off. |

| `valdec(#)` | Fixed number of decimals for flow values and category percentages, so printed values add up. Takes precedence over `valdec1`. |
| `pctbase` | With `percent2`, shows category percentages as a share of the first column (the same base as the flow values) instead of each column. Labels only. |
| `stagen` | **Funnel view** for samples that shrink from stage to stage. Each column is drawn as 100% of those who reached it, category labels show the share of their own column, and **flow values are counts**, so flows at each stage add up to the people at that stage. Box heights and ribbon widths use the same base, so they agree. Prints a note with the number of observations dropped because of a missing answer. Implies `percent2`. |

All default to **off**.

## Examples

```stata
alluvial group stage1 stage2 outcome, percent2 showtotal ///
    valdec1 valnudge(4)
```

Tuning: if labels still touch, raise `valnudge` (e.g. `6`–`8`); if the plot
looks too spread out, lower it.

Funnel where later questions are only asked of a subset:

```stata
alluvial all problem fault redress satisfied if !mi(problem), ///
    stagen showtotal valdec1 valnudge(4) novalleft
```

Restricting with `if !mi(firstvar)` makes the first column equal the N you
report, so the first split adds to 100%.

## Install

```stata
net install alluvial, ///
    from("https://raw.githubusercontent.com/Mupela/alluvial-fork/main") replace
```

Or just copy `alluvial.ado` and `alluvial.sthlp` into your Stata `adopath`
(e.g. `PERSONAL`).

### Dependencies (from the original package)

```stata
ssc install palettes, replace
ssc install colrspace, replace
ssc install graphfunctions, replace
```

## What changed in the code

All additions are marked with `IPA` comments in `alluvial.ado`:

- a `valdec1` / `valnudge(real 0)` entry in the `syntax` line;
- conditional formatting of the category label and the flow-value label;
- a `_laby` variable that greedily de-collides value labels, computed with the
  draw order preserved and restored so the flow ribbons still render correctly;
- for `stagen`: per-node counts (`_nraw`) and column totals (`_colN`) computed
  over flows with no missing end, used to size boxes (% of column) and ribbons
  (% of column 1) on one base, plus notes for observations that are not drawn.

## Credit & license

Original command © Asjad Naqvi — <https://github.com/asjadnaqvi/stata-alluvial>
(distributed under the MIT License upstream). This repository is a modified copy;
the additions described above are the only changes. Please check the upstream
license before redistributing. See [`LICENSE`](LICENSE).
