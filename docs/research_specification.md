# Codex Research Project: Three EM Algorithms for Activity Imputation — Time Windows, Monte Carlo, Bootstrap, and Interactive R Markdown Report

## 1. Research objective

I am conducting a statistical methods project to compare three EM-based imputation models using activity data from multiple participants observed on the same calendar day.

I will provide two datasets:

- One weekday, with measurements from multiple participants.
- One weekend day, with measurements from multiple participants.

The models are:

1. Multivariate Gaussian normal EM.
2. Multivariate contaminated normal EM.
3. Multivariate Student's t EM.

Include two simple benchmarks alongside the three EM models:

4. **Zero-only benchmark:** predict zero for every artificially masked observation.
5. **Time-of-day mean benchmark:** predict the mean of the remaining observed values at the same clock-time interval across participants, separately for each calendar date/day type. For hourly data, use the corresponding hour's mean.

Evaluate all five methods on identical masked entries. Estimate time-of-day means anew after masking in each Monte Carlo repetition and each participant bootstrap sample. Exclude preexisting missing values and all artificially held-out values from those means; retain legitimate observed zeros. If an interval has no observed training values, record its mean prediction as unavailable and report the resulting evaluation coverage. For paired comparisons, use identical entries with available predictions and report their counts; do not silently omit failures or substitute zero.

The two benchmarks are comparison methods, not additional EM models. Retain them in held-out predictions, accuracy summaries, paired method comparisons, rankings, figures, and the report. Report performance separately for true zeros and positive outcomes so that the zero-only benchmark's behavior is visible.

The primary experiment artificially removes 10% of originally observed activity measurements under MCAR and compares the predictions with their original values.

**New research objective:** Determine whether prediction accuracy changes when fitting and evaluating the models on different time windows, particularly because nighttime activity contains many zeros.

I also want:

- Repeated Monte Carlo missingness experiments.
- Participant-level bootstrap uncertainty analysis.
- Statistical comparisons between models.
- Publication-quality scientific plots.
- Clean, reproducible R Markdown source.
- An attractive, interactive, liquid-glass-inspired HTML research report.

Reuse existing project scripts if available. Do not unnecessarily rebuild completed work.

---

## 2. Data structure

Organize the datasets as participant-by-time matrices.

Each row represents one participant, and each column represents a measurement interval within the selected calendar day.

Create separate data objects for weekday and weekend.

Preserve:

- Participant identifier.
- Calendar date.
- Time interval.
- Original activity value.
- Day type.
- Existing missingness indicator.

Verify data types, sampling intervals, participant counts, and original missingness.

Do not treat legitimate zero activity as missing.

If participants are observed on both dates, preserve the participant linkage for analyses that require it. Do not automatically assume independence between dates.

---

## 3. Compare three time-window definitions

I want to investigate how the time interval chosen for model fitting affects imputation accuracy.

Use the following initial definitions, with times interpreted in the datasets' local time zone:

| Window | Time interval | Research interpretation |
|---|---|---|
| Whole day | 00:00–24:00 | Includes sleeping and active periods |
| Daytime | 09:00–18:00 | Daytime activity from 9 a.m. to 6 p.m. |
| Evening | 18:00–24:00 | Lower activity and transition toward nighttime |

Define intervals as half-open: daytime is [09:00, 18:00), including hourly intervals starting at 09:00 through 17:00; 18:00 belongs to evening. Whole day intentionally contains the narrower windows. Daytime, evening, and nighttime do not overlap; 06:00–09:00 remains included in whole-day analysis only. Keep the nighttime diagnostic at [00:00, 06:00).

Allow window definitions to be edited in a configuration file.

If timestamps are intervals rather than point measurements, establish a consistent allocation rule.

### Important comparison

I want two complementary analyses.

**Analysis A: Window-specific model fitting**

Fit each of the three EM models separately on:

- Whole-day measurements.
- Daytime measurements.
- Evening measurements.

Compare prediction accuracy within each window.

**Analysis B: Whole-day versus window-specific training**

For the same artificially masked daytime observations, compare:

- A model fitted to the complete 24-hour data.
- A model fitted only to daytime data.

Repeat the same comparison for evening observations. Include both benchmarks as references. For a fixed mask and clock-time interval, these benchmarks have identical predictions under whole-day and window-specific fitting because they use no other hours; their fitting-window differences should therefore be zero wherever predictions are available.

This distinction is essential.

Do not conclude that daytime modeling is superior solely because daytime and whole-day RMSE values were calculated on different observations.

Use identical evaluation entries for direct whole-day versus window-specific comparisons.

### Additional diagnostic: Nighttime

Because nighttime activity may contain many zeros, calculate separate descriptive and prediction diagnostics for:

00:00–06:00.

Nighttime does not need to be a fourth primary modeling window, but it should be included in the diagnostic analysis to explain the role of zero-heavy observations.

---

## 4. Quantify zero inflation

Before fitting the models, investigate the proportion of zero values in each time window.

For weekday and weekend, calculate:

- Proportion of zero measurements.
- Mean activity.
- Median activity.
- Standard deviation.
- Proportion of positive measurements.
- Quantiles of positive activity.
- Skewness, where meaningful.
- Frequency of unusually high activity.

Create a table:

`results/descriptive/window_activity_summary.csv`

Investigate whether high zero frequency, nonnormality, and outliers could affect model performance.

Do not assume that a contaminated normal or Student's t model explicitly accounts for a point mass at zero. These are continuous distributions, not zero-inflated or hurdle models.

Discuss whether additional model classes might be appropriate in future research.

---

## 5. Generate 10% MCAR missingness

For each weekday/weekend dataset:

1. Identify originally observed measurements.
2. Artificially mask 10% of those entries uniformly at random.
3. Save the original values for later validation.
4. Ensure the missing positions are identical across all competing models.
5. Use reproducible seeds.
6. Do not mask preexisting missing values.

For the time-window comparison, generate masks from the full-day observed data and reuse the corresponding masked entries within each subset.

Do not generate an unrelated 10% mask for daytime when directly comparing whole-day and daytime fitting.

Also report the realized missingness proportion separately within every time window.

Save:

- Full-day masked data.
- Masked participant/time coordinates.
- Ground-truth values at masked positions.
- Random seed.
- Day type.
- Time-window membership.

Create a master missingness CSV.

Make sure the held-out original values cannot enter model fitting.

---

## 6. Implement the three EM models

### Model 1: Multivariate Gaussian EM

Assume:

\[
X_i\sim N_p(\mu,\Sigma).
\]

Use conditional multivariate normal expectations and second moments in the E-step.

Update the mean and covariance in the M-step.

Track observed-data likelihood, numerical stability, and convergence.

### Model 2: Contaminated Gaussian EM

Use a contaminated multivariate normal model such as:

\[
f(x)=\alpha\phi_p(x;\mu,\Sigma)
+(1-\alpha)\phi_p(x;\mu,\eta\Sigma),
\]

where \(\eta>1\).

Estimate the contamination probability and covariance inflation factor through a mathematically valid EM or ECM procedure.

Account for both latent contamination membership and missing observations.

### Model 3: Multivariate Student's t EM

Assume:

\[
X_i\sim t_p(\mu,\Sigma,\nu).
\]

Use a normal–gamma latent scale representation.

Implement the correct conditional moments for missing observations and latent scales.

Estimate or justify fixing the degrees of freedom.

### Shared implementation requirements

- Same masked data across models.
- Consistent numerical tolerances.
- Appropriate covariance regularization.
- Positive-definiteness checks.
- Reproducible initialization.
- Proper convergence diagnostics.
- Explicit recording of failed fits.
- Correct conditional mean predictions.

Do not call a method exact EM if it actually uses an ECM or generalized EM update; identify the optimization scheme precisely.

If the number of time intervals exceeds the number of participants or covariance estimation is poorly conditioned, implement a defensible shared covariance structure or dimension-reduction approach.

Do not use different structural advantages for different models without a justified comparison.

---

## 7. Monte Carlo experiment

Conduct repeated artificial missingness experiments.

Primary settings:

- Missingness mechanism: MCAR.
- Missingness percentage: 10%.
- Target repetitions: 200.
- Day types: weekday and weekend.
- Methods: three EM distributions plus zero-only and time-of-day mean benchmarks (five methods total).
- Primary fitting windows: whole day, daytime, evening.

Use a configuration file for repetition counts and random seeds.

### Simulation procedure

For each repetition:

1. Generate a new MCAR mask.
2. Keep the same mask across all competing models.
3. Fit each EM model under each relevant window definition and compute both benchmarks from the same masked training data.
4. Predict the artificially missing observations.
5. Compare predictions against the held-out original values.
6. Record error measures, convergence, and runtime.

When a window has no masked entries in a repetition, record the metric as not estimable rather than assigning zero error.

### Evaluation metrics

Calculate:

- RMSE.
- MAE.
- Mean prediction bias.
- Median absolute error.
- Runtime.
- Convergence rate for EM models; mark benchmark convergence as not applicable and report benchmark availability separately.

Also calculate performance separately for:

- True zero observations.
- True positive observations.
- Low-activity measurements.
- High-activity measurements.

Use explicit, prespecified definitions for activity categories.

This allows us to determine whether a model's apparent whole-day accuracy is mostly explained by its performance on zeros.

### Aggregate Monte Carlo results

Report mean, median, standard deviation, and Monte Carlo confidence intervals for the model performance metrics.

Use paired replicate-level comparisons because the models are tested on the same masked observations.

Avoid making inferential claims from repetitions as though each repetition were an independent participant sample.

---

## 8. Bootstrap uncertainty analysis

In addition to Monte Carlo masking experiments, I want bootstrap estimates of uncertainty in model performance.

**Bootstrap at the participant level, not the individual measurement level.**

This preserves the dependence between measurements within each participant.

Use a target of 500 bootstrap samples, subject to computational feasibility.

For each bootstrap sample:

1. Sample participants with replacement.
2. Preserve the complete within-participant time sequence.
3. Preserve day-type membership.
4. Refit the relevant models using the appropriate bootstrap training data.
5. Evaluate predictions using a clearly specified validation scheme.
6. Record performance metrics and model differences.

If the same participants appear on both weekday and weekend, consider resampling linked participants as clusters when making combined conclusions.

Distinguish clearly between:

- Monte Carlo variation due to different artificial missingness masks.
- Bootstrap variation due to which participants are sampled.

Do not pool these sources of uncertainty without a justified nested design.

### Bootstrap confidence intervals

Calculate percentile bootstrap 95% confidence intervals for:

- Mean RMSE.
- Mean MAE.
- Paired RMSE differences between models.
- Paired MAE differences between models.
- Whole-day versus window-specific fitting differences.

Explain which population-level interpretation the bootstrap supports.

When evaluating performance for the original participant sample versus a broader participant population, distinguish the estimands.

---

## 9. Optional nested Monte Carlo and bootstrap experiment

If computational resources permit, add a smaller nested experiment.

Suggested design:

- 100 participant bootstrap samples.
- 20 MCAR repetitions per bootstrap sample.

This provides insight into both participant-sampling variability and random missingness variability.

Make this optional and execute it only if the computational budget permits.

Report the exact completed repetitions and failures.

Do not replace the primary study with a computationally infeasible simulation plan.

---

## 10. Fair model evaluation

I want two types of comparisons.

### Comparison 1: Three distributions and two benchmarks within each window

For each day and window, compare:

- Gaussian EM.
- Contaminated Gaussian EM.
- Student's t EM.
- Zero-only benchmark.
- Time-of-day mean benchmark.

Use the same masked entries and evaluation observations.

### Comparison 2: Fitting-window effects

For each model, compare whole-day fitting against window-specific fitting.

Evaluate both fits on the **same held-out entries**.

Calculate the paired difference:

\[
\Delta_{\mathrm{RMSE}}
=
\mathrm{RMSE}_{\mathrm{window-specific}}
-
\mathrm{RMSE}_{\mathrm{whole-day}}.
\]

Interpret:

- Negative: Window-specific fitting performed better.
- Positive: Whole-day fitting performed better.
- Near zero: Little observed difference.

Use confidence intervals to assess uncertainty.

Do not compare whole-day RMSE against daytime RMSE as if they measure error on an identical target population.

Also investigate whether unequal window lengths create differences in estimation difficulty, covariance dimensions, and effective sample sizes.

---

## 11. Publication-quality scientific figures

Generate the following figures only when supported by the data.

### Figure 1: Daily activity patterns

Mean activity profiles for weekday and weekend.

Indicate daytime, evening, and nighttime boundaries.

### Figure 2: Distribution and zero frequency

Show the distribution of activity values and zero proportions for each time window.

### Figure 3: Monte Carlo model accuracy

Compare RMSE and MAE distributions across:

- Three EM models and both benchmarks.
- Three fitting windows.
- Two day types.

### Figure 4: Whole-day versus window-specific fitting

Plot paired RMSE differences for daytime and evening.

Include bootstrap uncertainty intervals.

### Figure 5: Errors by original activity level

Compare error for truly zero, low-positive, and high-positive measurements.

### Figure 6: Original versus imputed values

Scatter plots with an identity line, faceted by model and day type.

### Figure 7: Example activity trajectories

Show original activity, masked observations, and three model predictions for representative participants.

### Figure 8: Stability and uncertainty

Compare Monte Carlo variability and bootstrap confidence intervals.

Use accessible colors, readable legends, and scientific figure captions.

Export figures as vector PDFs and 300–600 dpi PNGs.

---

## 12. Clean results structure

Organize the project as:

```text
EM_Activity_Project/
├── data/
│   ├── raw/
│   └── processed/
├── R/
│   ├── data_preparation.R
│   ├── missingness_mcar.R
│   ├── gaussian_em.R
│   ├── contaminated_normal_em.R
│   ├── student_t_em.R
│   ├── prediction.R
│   ├── evaluation.R
│   ├── monte_carlo.R
│   ├── bootstrap.R
│   └── visualization.R
├── results/
│   ├── descriptive/
│   ├── missingness/
│   ├── predictions/
│   ├── monte_carlo/
│   ├── bootstrap/
│   ├── model_comparisons/
│   └── figures/
├── report/
│   ├── EM_Activity_Research_Report.Rmd
│   ├── custom.css
│   ├── custom.js
│   └── assets/
├── config.yml
├── renv.lock
└── README.md
```

Do not generate excessive duplicate CSVs.

Every output must serve a clear research, verification, or reporting purpose.

---

## 13. Main numerical outputs

At minimum, create:

`results/descriptive/window_activity_summary.csv`

`results/missingness/mcar_mask_coordinates.csv`

`results/predictions/heldout_predictions.csv`

`results/monte_carlo/replicate_metrics.csv`

`results/monte_carlo/monte_carlo_summary.csv`

`results/bootstrap/bootstrap_metrics.csv`

`results/bootstrap/bootstrap_confidence_intervals.csv`

`results/model_comparisons/paired_model_comparisons.csv`

`results/model_comparisons/window_comparisons.csv`

`results/model_comparisons/final_model_ranking.csv`

`results/model_comparisons/convergence_summary.csv`

The held-out predictions file must contain original values and predictions for each of the five methods, tied to participant, time interval, date, replication ID, and evaluation window.

Store all required information for reproducing each figure and table.

---

## 14. Create one complete R Markdown scientific report

The primary report must be an editable and reproducible `.Rmd` file.

Filename:

`report/EM_Activity_Research_Report.Rmd`

Render it to:

`report/EM_Activity_Research_Report.html`

The R Markdown report must:

- Load actual results from the project.
- Produce scientific tables and plots from the CSVs.
- Include mathematical derivations of the three EM models.
- Explain the Monte Carlo design.
- Explain the participant-level bootstrap.
- Compare time-window performance.
- Interpret the actual findings.
- Report uncertainty and convergence issues.
- Include references and reproducibility information.
- Render without manual editing of intermediate outputs.

Use `rmarkdown`, `knitr`, `ggplot2`, and suitable interactive HTML libraries where needed.

Make the report self-contained if practical, and ensure it remains functional offline.

---

## 15. Liquid-glass-inspired interactive HTML design

I want the HTML to have a polished, modern, macOS-inspired liquid-glass appearance, while remaining a credible scientific research report.

### Visual direction

Use:

- Translucent frosted panels.
- Soft blur effects.
- Subtle borders and restrained shadows.
- Rounded corners.
- White or gently tinted background.
- Muted blue, gray, and teal accents.
- Clear scientific typography.
- Generous spacing.
- Smooth but minimal transitions.

Avoid excessive gradients, animations, decorative graphics, and distracting effects.

The report must remain easy to read and appropriate for a graduate statistics research presentation.

### Interactive features

Include:

**1. Navigation**

A floating or sticky table of contents with links to the study sections.

**2. Experimental configuration overview**

Interactive controls or filters allowing readers to explore:

- Weekday versus weekend.
- Whole day versus daytime versus evening.
- Gaussian versus contaminated Gaussian versus Student's t versus zero-only versus time-of-day mean.
- RMSE versus MAE.

**3. Interactive scientific plots**

Use Plotly or another suitable R-compatible plotting library for:

- Hoverable model performance plots.
- Interactive activity trajectories.
- Model accuracy comparisons.
- Monte Carlo result exploration.

**4. Searchable data tables**

Use `DT` or an equivalent R package to show:

- Model performance summaries.
- Bootstrap confidence intervals.
- Pairwise comparisons.
- Convergence diagnostics.

**5. Statistical explanations**

Add collapsible technical sections for:

- Gaussian EM derivation.
- Contaminated Gaussian EM derivation.
- Student's t EM derivation.
- Monte Carlo methods.
- Bootstrap design.

**6. Summary dashboard**

At the top of the report, provide compact summary metrics such as:

- Number of participants.
- Total observed measurements.
- Artificially masked percentage.
- Completed Monte Carlo replications.
- Completed bootstrap samples.
- Best-performing model for each day and window, where supported.

All summary values must come directly from the results.

### Technical requirements

Use a custom `custom.css` and minimal `custom.js`.

Prefer standard R Markdown-compatible HTML dependencies.

Ensure that plots and tables are functional within the rendered HTML rather than being static screenshots.

Support responsive desktop and mobile layouts.

Provide graceful fallback for browsers without background blur support.

Keep scientific equations, tables, and text legible regardless of transparency effects.

If the report is self-contained, ensure all necessary assets are embedded correctly.

Do not prioritize appearance over mathematical or scientific correctness.

---

## 16. Scientific report structure

The R Markdown report should include:

### Abstract

Summarize the study objective, methods, and actual results.

### 1. Introduction

Explain missing activity data and why robust distributional EM models may improve imputation.

Discuss nighttime zero-heavy data.

### 2. Research questions

1. Which of the three EM models gives the best imputation accuracy?
2. Does performance differ between weekday and weekend?
3. Does daytime-only or evening-only fitting outperform whole-day fitting for the same masked observations?
4. Are any improvements explained by the large proportion of zeros at night?
5. How reliable are the results across Monte Carlo masks and participant bootstrap samples?

### 3. Data description

Describe participants, time intervals, activity measurements, and observed distributions.

### 4. Statistical methodology

Include:

- Three multivariate distributions.
- EM/ECM algorithms.
- MCAR generation.
- Conditional prediction.
- Model evaluation metrics.
- Window comparisons.
- Monte Carlo simulation.
- Participant-level bootstrap inference.

### 5. Results

Include all necessary plots and statistical tables.

### 6. Discussion

Explain why models differ, where predictions are strongest or weakest, and how zero-heavy activity affects performance.

### 7. Limitations

Discuss:

- MCAR versus realistic missingness.
- Only one weekday and one weekend.
- Dependence across participants and/or dates.
- Zero inflation.
- Model misspecification.
- High-dimensional covariance estimation.
- Generalizability of findings.

### 8. Conclusion

Identify the best-supported model and training window for each selected day, with uncertainty.

### Appendix

Include detailed EM derivations, convergence diagnostics, extra tables, and session information.

---

## 17. Final quality assurance

Before completing the project:

1. Verify the 10% MCAR masking.
2. Confirm no held-out value enters model fitting.
3. Verify all models use identical masks.
4. Validate the E-step and M-step implementations.
5. Confirm the models are fitted to the intended windows.
6. Verify that direct window comparisons use identical evaluation entries.
7. Check that Monte Carlo replicates are reproducible.
8. Confirm bootstrap resampling occurs at participant level.
9. Check convergence and covariance conditioning.
10. Ensure every reported numerical result comes from a generated output.
11. Confirm the `.Rmd` compiles successfully to HTML.
12. Test interactive plots, data tables, and navigation.
13. Ensure CSS effects do not obstruct reading or printing.
14. Generate a clean README with execution instructions.

Do not report unavailable simulations as complete.

Do not claim statistical significance or model superiority without supporting estimates and uncertainty.

---

## 18. Final deliverables and interpretation

Generate:

1. A complete reproducible R project.
2. Validated implementations of three EM-based models.
3. MCAR masking CSVs and held-out predictions.
4. Monte Carlo accuracy comparison.
5. Participant bootstrap confidence intervals.
6. Whole-day, daytime, evening, and nighttime diagnostic comparisons.
7. Publication-quality PDF and PNG figures.
8. An editable R Markdown research report.
9. A fully rendered interactive liquid-glass-style HTML report.
10. A README explaining the project.

At the end, give me a clear statistical interpretation answering:

**Which EM distribution performs best for activity data, whether time-window-specific modeling improves prediction compared with full-day modeling, and whether the apparent performance advantage is robust to Monte Carlo masking variation and participant-level bootstrap uncertainty.**

Use the actual data to determine the answers. Do not assume the heavy-tailed models or daytime-only models will necessarily perform better.