# Humans use a dual policy to improve inferences during epistemic information seeking

Code and data for:

Yinan Cao, Clémence Alméras, Junseok K. Lee, Inès Maye and Valentin Wyart. *Humans use a dual policy to improve inferences during epistemic information seeking.* (*Nature Human Behaviour*, accepted)

This repository contains the behavioral data of the four studies, the code for model fitting and simulation, the recurrent neural network (RNN) code and trained networks, and the scripts that reproduce the main figures (except the schematics in Figs. 1a, 3a and 6a), Supplementary Figures 1 to 5 and the Source Data. Figure 6 is made in Python; all other figures are made in MATLAB.

---

## Quick start

**MATLAB figures.** First add the repository folders to the MATLAB path, once per MATLAB session. In MATLAB, go to the repository root (the folder that contains `setup_paths.m`) and type

```matlab
setup_paths
```

or open `setup_paths.m` and press **Run**. Then open any script in `code/figures` (for example `fig2.m`) and press **Run**. Without this step the scripts cannot find the data files and helper functions.

**Python figures (Fig. 6).** From the repository root (the scripts also work from any other folder, with the path adjusted):

```
python code/figures/fig6bc.py     # Fig. 6b, c
python code/figures/fig6d.py      # Fig. 6d
```

The scripts load the trained networks from `code/rnn/saved_runs` and also save PDF versions of the panels in a folder `rnnFigs/` in the current folder.

---

## Requirements

**MATLAB** R2023a or later (the paper used R2024b), with the Statistics and Machine Learning Toolbox and the Bioinformatics Toolbox (`mafdr`, used for false discovery rate correction). All other MATLAB code is included: helper functions and colormaps in `code/utils/func`, the SPM functions used for Bayesian model selection in `code/utils/func/spm`, and the BADS and VBMC toolboxes used for model fitting in `code/utils/toolbox`.

**Python** 3 (the paper used Python 3.11 and PyTorch 2.7.0) with NumPy, SciPy, PyTorch, Matplotlib (with a Qt backend, for example PyQt5 or PyQt6), seaborn and scikit-learn. To regenerate the Source Data for Fig. 6, also pandas and openpyxl:

```
pip install numpy scipy torch matplotlib pyqt5 seaborn scikit-learn pandas openpyxl
```

---

## Repository structure

```
InfoSeek/
├── setup_paths.m            adds the code and data folders to the MATLAB path
├── LICENSE                  MIT licence (code)
├── LICENSE-DATA             CC BY 4.0 licence (data and Source Data)
├── CITATION.cff             how to cite this work
├── code/
│   ├── figures/             one script per figure (see the table below)
│   ├── model/               model fitting (run_fit_*.m, fit_*.m) and simulation (sim_*.m)
│   ├── rnn/                 RNN code (rnnModules.py, train_rnn.py) and trained networks (saved_runs/)
│   ├── source_data/         scripts that write the Source Data files
│   └── utils/
│       ├── func/            helper functions, including SPM functions (spm/)
│       ├── toolbox/         BADS and VBMC
│       └── data_export/     scripts that wrote the .csv data files from the .mat files
├── data/
│   ├── raw/                 trial-level behavioral data (.csv), one file per study
│   └── derived/             the same data as MATLAB tables, and the model fits (.mat)
├── experiment/              code used to run the four studies
└── source_data/             Source Data for the main figures (.xlsx)
```

---

## Figures

| Figure | Script | Language |
|---|---|---|
| Fig. 1b | `code/figures/fig1.m` | MATLAB |
| Fig. 2 | `code/figures/fig2.m` | MATLAB |
| Fig. 3b | `code/figures/fig3b.m` | MATLAB |
| Fig. 4 | `code/figures/fig4.m` | MATLAB |
| Fig. 5 | `code/figures/fig5.m` | MATLAB |
| Fig. 6b, c | `code/figures/fig6bc.py` | Python |
| Fig. 6d | `code/figures/fig6d.py` | Python |
| Fig. 7a to d | `code/figures/fig7abcd.m` | MATLAB |
| Fig. 7e to h | `code/figures/fig7efgh.m` | MATLAB |
| Fig. 8 | `code/figures/fig8.m` | MATLAB |
| Supplementary Figs. 1 to 5 | `code/figures/figS1.m` to `figS5.m` | MATLAB |

Panels 1a, 3a and 6a are schematics.

The scripts also print the statistics reported in the text to the MATLAB Command Window (or the Python console). `fig8.m` prints Supplementary Tables 1 to 5 and can also write them to an Excel file (set `SAVE_STATS = true` at the top of the script).

**Model simulations.** `fig4.m` and `fig5.m` simulate the fitted model for every participant. `Nsim`, at the top of each script, sets the number of simulations per participant; the published figures use 1,000. With 1,000 simulations the scripts take a long time; a smaller value (for example 10) gives a quick, slightly noisier version of the same figure. In `figS5.m` the same setting is called `nSim`. Random seeds are fixed, so the results are reproducible.

**Naming.** In some variable names, data columns and RNN file names, *bandit* refers to the match condition.

---

## Source Data

`source_data/SourceData_FigN.xlsx` holds the Source Data for each main figure with graphs (Figs. 2 to 8). Each file has a README sheet and one sheet per panel. Each panel sheet gives the plotted summary (for example, mean and 95% CI, with the exact P value of every test drawn in the figure) followed by the participant-level values the summary is computed from (RNN-instance values for Fig. 6).

To regenerate them, run the matching script in `code/source_data` (it sets the path, runs the figure script and then writes the file). From the repository root:

```matlab
run('code/source_data/export_fig2.m')   % likewise export_fig3, 4, 5, 7, 8
```

```
python code/source_data/export_fig6.py
```

For Figs. 4 and 5, set `Nsim = 1000` in `fig4.m` and `fig5.m` first, so that the Source Data match the published figures.

---

## Behavioral data

The figure and model-fitting scripts use the MATLAB tables in `data/derived` for convenience. The same trial-level data are provided as `.csv` files in `data/raw`, with one row per sampling choice.

### `data/raw/dat_sampling_COLINE.csv`

Main online study (**N = 420**; participants excluded from the analyses are not included in this file).

- `subj`: participant ID
- `blk`: block index (1 to 4)
- `seq`: sequence (game) index
- `condition`: `1` = match, `2` = guess
- `symmetry`: `1` or `2` = both bags have the same dominant color; `3` = the two bags have opposite dominant colors
- `counterfactual`: `1` = the two bags have opposite dominant colors (same games as `symmetry = 3`)
- `targetcolor`: target color in the match condition, `1` = blue, `2` = orange
- `nsamples`: number of choices in the game (8, 12, 16 or 20)
- `mirroring`: seed-sequence index shared between match and guess games
- `finalchoicecorr`: final-probe answer correct (`1`) or not (`0`); guess condition only
- `finalchoicert`: final-probe response time (ms)
- `coloroption1`, `coloroption2`: color shade that option 1 and option 2 would show on this choice (8 shades from `-1` = most blue to `+1` = most orange)
- `colorseen1`, `colorseen2`: color shade seen on this choice (empty for the option not chosen)
- `choices`: sampled option (`1` = option 1, `2` = option 2); options do **not** correspond to spatial sides. `0` marks a missing response; games with a missing response are excluded from the analyses
- `choicesrt`: choice response time (ms)
- `big5_extraversion`, `big5_agreeableness`, `big5_conscientiousness`, `big5_negativeemotionality`, `big5_openmindedness`: Big Five personality domain scores
- `icar`: ICAR cognitive ability score
- `nfcs`: Need for Closure score
- `female`: `1` = female, `0` = otherwise
- `age`: age in years

Questionnaire and cognitive scores are unavailable (coded `0`) for participants who did not complete the corresponding measures.

### `data/raw/dat_sampling_COLINEternary.csv`

Ternary-choice online study (Supplementary Fig. 3). The file contains 250 participants; 7 of them (`subj` 8, 41, 84, 128, 192, 208 and 244) are excluded from the analyses, which leaves **N = 243**.

- `condition`: `1` = match, `2` = guess
- `symmetry`: number of bags with blue as the dominant color (0 to 3)
- `latent1`, `latent2`, `latent3`: true dominant color of each option (`-1` = blue bag, `+1` = orange bag)
- `coloroption1` to `coloroption3`, `colorseen1` to `colorseen3`, `choices` (`1` to `3`): as above, for three options
- Other columns as in the main study.

### `data/raw/dat_sampling_COLdiscEEG.csv`

Laboratory replication study with novel stimuli (**N = 39**; Supplementary Fig. 2). Outcomes were shown as black-line positions on a circular color disc, so the color values are continuous.

- `condition`: `1` = match, `2` = guess
- `symmetry`: as in the main study
- `twinid`: seed-sequence index identifying replicated sequences
- `mirroring`: seed-sequence index shared between match and guess games
- `targetcolor`: `1` = blue, `2` = orange
- `nsamples`: number of choices in the game (8, 14 or 20)
- `latent1`, `latent2`: true dominant color of each option (`-1` = blue bag, `+1` = orange bag)
- `finalchoicecorr1`, `finalchoicecorr2`, `finalchoicert1`, `finalchoicert2`: correctness and response time of the two final-probe answers
- Other columns as in the main study.

### `data/raw/dat_sampling_COLcued.csv`

Cued-sampling online study (guess condition only; Fig. 7e to h). 150 participants took part; 9 with mean final-probe accuracy below 60% were excluded, which leaves **N = 141** (the participants in this file).

- `condition`: `2` = guess
- `choicetype`: `0` = free choice, `1` = cued streaking, `2` = cued non-streaking
- `symmetry`: number of bags with blue as the dominant color (0 to 2)
- `latent1`, `latent2`: true dominant color of each option (`-1` = blue bag, `+1` = orange bag)
- `finalchoicecorr1`, `finalchoicecorr2`, `finalchoicert1`, `finalchoicert2`: correctness and response time of the two final-probe answers
- `choices`: sampled option (`1` = option 1, `2` = option 2); options do **not** correspond to spatial sides
- Other columns as in the main study.

### `data/derived/*.mat`

- `dat_choicestbl_<study>.mat`: trial-level data of each study as a MATLAB table (`choicestbl`), one row per game. These tables also contain the participants who were excluded, flagged in the column `excludepart` (and `excludepart_possible` for the ternary-choice study); the scripts remove them. In the laboratory replication study, participant 23 is excluded in `figS2.m`, which leaves 39 of the 40 participants in `dat_choicestbl_COLdiscEEG.mat`.
- `dat_modelparELBO_COLINE.mat`: model fits for the main study (table `modelfit`): posterior-mean parameters and ELBO for every participant, condition and model (1 = exact, 2 = leak, 3 = noise, 4 = leak + noise, 5 = leak + noise without initial threshold).
- `dat_modeltbl_COLINE_full.mat`: the same fits, with human and model-predicted guess accuracy by sequence length (table `modelout`; Fig. 8).
- `dat_modeltbl_COLINE_exact-selnoise.mat`: fits of the noisy-responses model (exact inference with response noise at the final probe; Fig. 8).
- `dat_CountmodelparELBO_COLINE.mat`: fits of the count-based model variant (Supplementary Fig. 1).
- `dat_bigtbl_COLINE.mat`: participant-level questionnaire scores (Big Five, ICAR, NFCS), age and sex (Fig. 8).

---

## Model fitting (MATLAB)

Run `setup_paths` first (see Quick start). See `code/model/model_fitting_script.m` for an example. For instance, to fit the full model (leak + noise) to one participant of the main study:

```matlab
run_fit_comleak('1', 'comleaknoise', 'COLINE')
```

- The first argument is the position of the participant in the list of included participants, given as a string (convenient for SLURM job arrays).
- The second argument is the model: `'exact'`, `'comleak'` (leak), `'noise'`, `'comleaknoise'` (leak + noise) or `'comleaknoiseNOthres'` (leak + noise without the initial threshold, θ = 0). Further variants are listed in `run_fit_comleak.m`.
- The third argument is the study: `'COLINE'`, `'COLdiscEEG'` (use `run_fit_comleak_INFresp.m`) or `'COLINEternary'` (use `run_fit_comleak_3bags.m`).

Point estimates are first obtained with BADS (10 random starting points per parameter) and then used to initialize VBMC, which estimates the joint posterior and the ELBO. The parameter priors are defined in the fitting scripts. Results are saved in a folder `fit_<study>` in the current MATLAB folder.

---

## RNN training (Python)

The Python code trains recurrent neural networks on the sequential sampling task in two modes: **bandit** (the match condition) and **guess**. At each trial the network receives a two-dimensional input and maintains internal state estimates that it uses to generate the next sampling choice. Training sequences are generated online during training.

- `code/rnn/train_rnn.py`: standalone training script
- `code/rnn/rnnModules.py`: RNN architecture, data generation and utilities
- `code/rnn/saved_runs/`: trained networks used for Fig. 6

From `code/rnn`, run:

```
python train_rnn.py
```

This uses the default parameters defined in `train_rnn.py`. Optional command-line arguments, in this order:

```
python train_rnn.py <subject_id> <hidden_size> <task> <loss_function> <target_color> <noise_SD> <XEntLoss_type>
```

For example:

```
python train_rnn.py 1 64 guess hybrid 1 0.0 1
```

The default settings are:

- hidden units: `64`
- task: `guess` (or `bandit` for the match condition)
- loss function: `hybrid` (state prediction plus meta-policy); `xEntro` = state prediction only; `pGrad` = policy gradient (match)
- target color: `1`
- noise SD: `0.0`
- cross-entropy loss type: `1`
- training epochs: `50000`
- learning rate: `0.0001`

Training logs and checkpoints are written to `saved_runs_50000/` in the current folder.

---

## Experiment code

`experiment/` holds the code used to run the four studies:

| Folder | Study |
|---|---|
| `COLEXP/` | main online study |
| `ternary/` | ternary-choice online study |
| `cued/` | cued-choice online study |
| `replication/` | laboratory replication study |

**Online studies** (`COLEXP`, `ternary`, `cued`). Each folder is a Node.js (Express) app. It serves the task, written with jsPsych 6.3.0 (`public/exec_task.js`, `frontend/run_task.html`), and stores the responses in a MySQL database (`utils/database.js`, `utils/dbFunctions.js`). The pre-generated game sequences are in `data/`, one folder per sequence set (`000TRAINING` holds the practice games). To run a study locally, install the dependencies with `npm install`, set the MySQL connection in `utils/database.js`, and start the server with `node app.js`. In `COLEXP/csv_generation`, the MATLAB script `gen_online_task.m` generates the game sequences (see the README in that folder).

**Laboratory study** (`replication/`). MATLAB with Psychtoolbox-3. `expcode/Allrunner.m` runs the tutorial, the practice games and the main task. Set the participant number in `expcode/subj_info.m`; the game sequences of each participant are in `sqcfiles/`. Before running, change the folder path in the `cd` line at the top of `Allrunner.m` and `main_runner.m`. `main_runner.m` also has switches for EEG and eye-tracking recording (`eegON`, `eyeON`).

---

## Licence and citation

The code is released under the MIT licence (`LICENSE`). The data (`data/`) and the Source Data (`source_data/`) are released under the Creative Commons Attribution 4.0 International licence (CC BY 4.0; `LICENSE-DATA`): anyone may use, share and adapt them, provided they cite the paper. Third-party code included in this repository (BADS, VBMC, the SPM functions, jsPsych, jQuery and the other bundled libraries) keeps its own licence.

If you use the data or the code, please cite the paper (see `CITATION.cff`).

---

## Contact

Yinan Cao (ycaoneuro@gmail.com) and Valentin Wyart (valentin.wyart@inserm.fr).
