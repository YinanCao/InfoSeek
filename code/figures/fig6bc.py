#%%
import torch
import pickle
import numpy as np
import matplotlib
import matplotlib.pyplot as plt
from pathlib import Path
from scipy.stats import zscore
matplotlib.use("QtAgg")
import seaborn as sns
colors = sns.color_palette('muted', 8)
colors = sns.color_palette('deep')
colors = sns.color_palette('colorblind')
# Pick 4 pleasant colors:
colors = [colors[2], colors[3], colors[9], colors[6]]

import sys

# Make code/rnn importable and locate the trained networks,
# independent of the folder this script is run from.
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "code" / "rnn"))

from rnnModules import (
    CustomRNN,
    generate_sequences,
    make_input_tensor,
    run_traineval_loop,
    run_traineval_loop_forcedActions,
    simulate_optimal,
    sim_modelbound_noisyleaky,
    compute_pRepeatNext,
    compute_uncertaintyDirectedChoice,
    compute_targetDirectedChoice,
    get_cfac,
)

SEED = 12345
np.random.seed(SEED)
torch.manual_seed(SEED)
rng = np.random.default_rng(SEED)

device = torch.device("cpu")

# Parameters
loss_functions = {
    "bandit": ["pGrad"],   # bandit tasks use policy gradient loss
    "guess": ["xEntro", 'hybrid'],   # guess tasks use cross-entropy loss
}
target_colors = {
    "bandit": ["ora"],   # bandit has two possible target colors
    "guess": ["non"],           # guess task always 'non'
}
subjects = range(1, 26)         # subj1 ... subj10
base_dir = ROOT / "code" / "rnn" / "saved_runs"

test_noises = [0., 0.]

n_trials = 20
n_games = 1000
targetcolor = 1  # adjust as needed
sequence_lengths = range(1, n_trials + 1)
conditions = [(1, 0), (0, 1), (0, 0), (1, 1)]

n_subj = len(subjects)
n_test = 1
n_seq = n_trials
n_models = sum(len(losses) * len(target_colors[task]) for task, losses in loss_functions.items())

accuracy = torch.full((n_subj, n_test, n_seq, n_models), float('nan'))
acc_Bayes = torch.full((n_subj, n_test, n_seq, n_models), float('nan'))
pv = torch.full((n_subj, n_test, n_models, n_trials-1), float('nan'))
pc = torch.full((n_subj, n_test, n_models, n_trials-1), float('nan'))
pr = torch.full((n_subj, n_test, n_models, 10), float('nan'))
# nbin = 6  (original)
nbin = 8  # same number of evidence levels as the 8 colour shades in the human task
pr_signed = torch.full((n_subj, n_test, n_models, nbin), float('nan'))

test_i = 0
for iter in range(n_test):
    sub_i = 0
    for subj in subjects:
        seq_i = 0
        for ntrl in sequence_lengths:
            # ------------------------------
            # Step 1: Generate test data
            # ------------------------------
            input_tensor_opt1, input_tensor_opt2, target = generate_sequences(ntrl, n_games, conditions, rng=rng)
            input_tensors = make_input_tensor(input_tensor_opt1, input_tensor_opt2)
            model_i = 0
            for task, losses in loss_functions.items():
                for loss in losses:
                    for color in target_colors[task]:
                        fname = (
                            f"n064_noise=000_loss={loss}_"
                            f"subj{subj}_{task}_targcolor={color}_"
                            f"run00_pStatesOUT_weights.pt"
                        )
                        fpath = base_dir / fname
                        print(fpath)
                        if not fpath.exists():
                            print(f"Missing: {fpath}")
                            continue

                        if task=='bandit':
                            test_noise_value = test_noises[0]
                        elif task=='guess':
                            test_noise_value = test_noises[1]

                        print(f"Running with test_noise = {test_noise_value}")

                        checkpoint = torch.load(fpath, map_location=device)
                        model_kwargs = checkpoint["model_kwargs"]
                        state_dict = checkpoint["state_dict"]
                        model_kwargs["noise_value"] = test_noise_value
                        model = CustomRNN(**model_kwargs)
                        model.load_state_dict(state_dict)
                        model.to(device)
                        model.eval()

                        with torch.no_grad():
                            output = run_traineval_loop(input_tensors, model, device, targetcolor)
                        
                        states_ex = output['states_ex']
                        p_states_ex = output['p_states_ex']
                        # states_ex.shape # [ngames, 2]
                        xxx = ((states_ex > 0).float() == target).float().mean()
                        accuracy[sub_i, test_i, seq_i, model_i] = ((states_ex > 0).float() == target).float().mean()

                        acc_prob = torch.where(target == 1, p_states_ex, 1 - p_states_ex).mean()
                        # accuracy2[sub_i, seq_i, model_i] = acc_prob

                        choice = output['chosen_actions'] # [ntrl, ngames]
                        cumV = output['cum_value_T']

                        cumv_optimal, act_optimal = simulate_optimal(choice, input_tensors, task)
                        # actions_optimal = torch.as_tensor(act_optimal, dtype=torch.long, device=device)
                        acc_symbolic_optimal = ((cumv_optimal[-1,:,:] > 0) == target).float().mean()
                        acc_symbolic_optimal.shape
      
                        acc_Bayes[sub_i, test_i, seq_i, model_i] = acc_symbolic_optimal

                        # choice = actions_optimal
                        # cumV = torch.as_tensor(cumv_optimal[1:,:,:], dtype=torch.long, device=device)
                    
                        if ntrl==n_trials:
                            prepeat = compute_pRepeatNext(choice)
                            pv[sub_i, test_i, model_i] = compute_targetDirectedChoice(choice[1:, :], cumV[:-1, :, :])
                            pc[sub_i, test_i, model_i] = compute_uncertaintyDirectedChoice(choice[1:, :], cumV[:-1, :, :])
                            pr[sub_i, test_i, model_i] = prepeat[0:10]

                            inputs = input_tensors * get_cfac(1/3)

                            states = output['states']
                            belief_aligned_evi = np.sign(states) * inputs
                            target_aligned_evi = inputs * targetcolor

                            if task == 'guess':
                                signed_evi = belief_aligned_evi
                            else:
                                signed_evi = target_aligned_evi

                            n_trials, n_batches, n_options = states.shape
                            
                            # bins = np.linspace(-1, 1, nbin+1)  # 10 bins  (original: covered only |evidence| < 1 logLR)
                            cfac_llr = get_cfac(1/3)  # colour shade -> logLR factor (about 1.4386)
                            bins = np.linspace(-cfac_llr, cfac_llr, nbin+1)  # full logLR range of the stimuli
                            bin_centers = 0.5 * (bins[:-1] + bins[1:])
                            # Collect values
                            aligned_evi = np.zeros((n_trials-1, n_batches))  # skip last trial for t+1
                            switch = np.zeros((n_trials-1, n_batches))
                            for t in range(n_trials - 1):
                                # Get current choice (0 or 1)
                                c = choice[t]
                                # Belief-aligned evidence for current choice
                                aligned_evi[t] = signed_evi[t, np.arange(n_batches), c]
                                # Did switch happen on next trial?
                                switch[t] = (choice[t+1] != choice[t]).float()
                            # Flatten all trials and batches
                            aligned_evi_flat = aligned_evi.flatten()
                            switch_flat = switch.flatten()
                            # Bin and compute mean switch prob per bin
                            mean_switch = []
                            for i in range(len(bins) - 1):
                                # idx = (aligned_evi_flat > bins[i]) & (aligned_evi_flat < bins[i+1])  (original)
                                # idx = (aligned_evi_flat > bins[i]) & (aligned_evi_flat <= bins[i+1])
                                # exclude zero evidence (first trial, no belief yet), as in the human analysis
                                idx = (aligned_evi_flat > bins[i]) & (aligned_evi_flat <= bins[i+1]) & (aligned_evi_flat != 0)
                                if np.sum(idx) > 0:
                                    mean_switch.append(np.mean(switch_flat[idx]))
                                else:
                                    mean_switch.append(np.nan)
                            mean_switch = np.array(mean_switch)
                            mean_switch = torch.from_numpy(mean_switch).float()
                            pr_signed[sub_i, test_i, model_i, :] = 1-mean_switch
                                
                        model_i += 1
            seq_i += 1
        sub_i += 1
    test_i += 1

nan_mask = torch.isnan(accuracy)
# Does the tensor contain any NaN at all?
has_nan = nan_mask.any().item()
print("Contains NaN:", has_nan)
print(accuracy.shape)
accuracy = accuracy.reshape(n_subj * n_test, n_seq, n_models)
print(accuracy.shape)

accuracy_Bayes = acc_Bayes.reshape(n_subj * n_test, n_seq, n_models)

pr_z = pr.reshape(n_subj * n_test, n_models, pr.shape[3])
pc_z = pc.reshape(n_subj * n_test, n_models, pc.shape[3])
pv_z = pv.reshape(n_subj * n_test, n_models, pv.shape[3])
pr_signed_z = pr_signed.reshape(n_subj * n_test, n_models, pr_signed.shape[3])

n_subj, n_models, n_trl = pr_z.shape

# save_path = base_dir / "RNN_sampling.pkl"
# with open(save_path, "wb") as f:
#     pickle.dump({
#         "pv_z": pv_z,
#         "pc_z": pc_z,
#         "pr_z": pr_z,
#         "pr_signed_z": pr_signed_z,
#         "bin_centers": bin_centers,
        
#     }, f)

# print(f"Saved z-scored predictors to {save_path}")

#%%
plt.close('all')
import matplotlib as mpl
mpl.rcParams['font.family'] = 'Helvetica'
fs = 11.5
mpl.rcParams['font.size'] = fs             # default font size for all text
mpl.rcParams['axes.titlesize'] = fs        # axis title
mpl.rcParams['axes.labelsize'] = fs        # x and y labels
mpl.rcParams['xtick.labelsize'] = fs       # x tick labels
mpl.rcParams['ytick.labelsize'] = fs       # y tick labels
mpl.rcParams['legend.fontsize'] = fs       # legend

import matplotlib.ticker as mticker
fig, axs = plt.subplots(1, 4, figsize=(9, 3), sharey=False)

colors = [(0.494, 0.184, 0.556),  # purple
          (0.5,   0.5,   0.5),
          (0.466, 0.674, 0.188),  # green
          ]    # grey
labels = ['match RNN', 'guess RNN (state only)', 'guess RNN (state + meta)', ]

panels = [('pv', pv_z), ('pc', pc_z), ('pr', pr_z), ('pr_signed', pr_signed_z)]
# noise_idx = 1  # second noise level

ylabel = ['p(policy-guided choice)','p(policy-guided choice)',
          'p(repeat next)','p(repeat next)']

titles = ['target guided', 'uncertainty guided','lack of early streaking','']

panel_i = 0
for ax, (title, arr) in zip(axs, panels):
    data = arr                 # shape: (n_subj, n_models, n_trl_panel)

    N = data.shape[1]
    if title=='pv':
        N = 1
 
    n_trl_panel = data.shape[-1]
    if panel_i<=1:
        x = np.arange(1, n_trl_panel + 1) + 1      # per-panel x
    else:
        x = np.arange(1, n_trl_panel + 1)

    if title=='pr_signed':
       x = bin_centers

    for m in range(N):
        d = data[:, m, :].cpu().numpy()   # [n_subj, n_trl_panel]
        mean = d.mean(axis=0)
        sem  = d.std(axis=0, ddof=1) / np.sqrt(d.shape[0]) * 1.96

        ax.plot(x, mean, color=colors[m], lw=2, label=labels[m])
        ax.fill_between(x, mean - sem, mean + sem,
                        color=colors[m], alpha=0.2, edgecolor='none')

    if title!='pr_signed':
        ax.axhline(0.5, color='black', lw=1, linestyle=(0, (5, 5)))
        ax.set_xticks([-1.4,-0.6,0.6,1.4])
    else:
        ax.axvline(0, color='black', lw=1, linestyle=(0, (5, 5)))
        # ax.set_xlabel('signed evidence')  (original)
        ax.set_xlabel('signed evidence (logLR)')
    
    ax.set_title(titles[panel_i], fontsize=fs, color='grey')
    
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)

    if panel_i <= 1:
        ax.set_yticks([0, 0.5, 1])
        ax.set_xticks([2,8,12,16,20])
        ax.set_xlabel('sampling trial')
        ax.set_xlim(1, 20)
    else:
        ax.set_yticks([0.5, 0.75, 1])
        ax.set_ylim([0.3, 1.0])
    
    if panel_i == 2:
        ax.set_xticks([1,4,7,10])
        ax.set_xlim([0.5, 10])
        ax.set_xlabel('times seen before')
    
    if panel_i == 3:
        # ax.set_xticks([-1,0,1])  (original)
        ax.set_xticks([-1.4, 0, 1.4])
        ax.set_xticklabels(['-1.4', '0', '1.4'])
        ax.set_xlim([-1.5, 1.5])
        # ax.set_ylim([0.3, 1.01])  (original)
        ax.set_ylim([0, 1.01])
        ax.set_yticks([0, 0.5, 1])

    ax.set_ylabel(ylabel[panel_i])
    # ax.set_xticks([-1.4,-0.6,0.6,1.4])
    panel_i += 1

    ax.yaxis.set_major_formatter(matplotlib.ticker.ScalarFormatter())
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda val, pos: f'{val:g}'))
    # ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('%.1f'))
    
# axs[0].set_ylabel('value (z)')
handles, lab = axs[1].get_legend_handles_labels()
# fig.legend(handles, lab, loc='lower center', ncol=3, frameon=False)
# fig.savefig("myfigure.pdf")

plt.tight_layout(rect=(0, 0.12, 1, 1))
plt.show(block=False)

import os
os.makedirs('rnnFigs', exist_ok=True)
plt.savefig('rnnFigs/fig6C.pdf', format='pdf', bbox_inches='tight')

#%
# plt.close('all')
import matplotlib.pyplot as plt
import numpy as np
import matplotlib as mpl
mpl.rcParams['font.family'] = 'Helvetica'
fs = 12
mpl.rcParams['font.size'] = fs             # default font size for all text
mpl.rcParams['axes.titlesize'] = fs        # axis title
mpl.rcParams['axes.labelsize'] = fs        # x and y labels
mpl.rcParams['xtick.labelsize'] = fs       # x tick labels
mpl.rcParams['ytick.labelsize'] = fs       # y tick labels
mpl.rcParams['legend.fontsize'] = fs       # legend

accuracy_plot = accuracy[:, :, 1:]

curves = [0, 1]
green = np.array([0.4660, 0.6740, 0.1880])
colors = ['grey', green]
labels = ['guess RNN (state only)', 'guess RNN (state + meta)']
noise_labels = ['','']

n_subj, n_seq, n_model = accuracy_plot.shape
x = np.arange(1, n_seq+1)

# fig, ax = plt.subplots(figsize=(5.1, 3), constrained_layout=True)
fig, ax = plt.subplots(figsize=(4.9, 2.5), constrained_layout=True)

human_mean = np.array([0.6993, 0.7939, 0.8172, 0.8303])
human_sem  = np.array([0.0084, 0.0085, 0.0082, 0.0085]) * 1.96
x_human = np.array([8, 12, 16, 20])

linestyles = ['solid', 'dashed']   # for noise_level 0 and 1

noise_i = 0
for idx, model_i in enumerate(curves):
    data = accuracy_plot[:, :, model_i]   # [n_subj, n_seq]
    mean = data.mean(0).numpy()
    sem  = data.std(0, unbiased=True).numpy() / np.sqrt(n_subj) * 1.96
    ax.plot(
        x, mean,
        color=colors[idx],
        lw=2,
        linestyle=linestyles[noise_i],
        # label=f"{labels[idx]} ($\\sigma={noise_val}$)",
        label=f"{labels[idx]} {noise_labels[noise_i]}"
    )
    ax.fill_between(x, mean-sem, mean+sem, color=colors[idx], 
                    alpha=0.3,
                    edgecolor='none',
    )

data = accuracy_Bayes[:, :, 2]
mean = data.mean(0).numpy()
sem  = data.std(0, unbiased=True).numpy() / np.sqrt(n_subj) * 1.96
ax.plot(
    x, mean,
    color='black',
    lw=1,
    linestyle='dashed', label = 'Bayes-optimal'
)
# ax.set_xlim(1, 20)
# --- Human data ---
ax.errorbar(
    x_human, human_mean, yerr=human_sem,
    fmt='o',
    mfc=green,   # marker face color
    mec='k',     # marker edge color
    mew=1.0,     # marker edge width
    ecolor='k',
    elinewidth=1,
    capsize=0,
    label='human',
    markersize=6,
)

ax.set_xlabel("sequence length")
ax.set_ylabel("guess accuracy")
ax.legend(frameon=False)
ax.legend(frameon=False, bbox_to_anchor=(1.05, 1), loc='upper left',fontsize=11)
# plt.tight_layout()

ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
plt.tight_layout()
plt.show(block=False)
ax.set_xticks([1,8,12,16,20])
ax.set_yticks([0.5, 0.9])
ax.set_yticks([0.5, 0.95])
# ax.set_title('out-of-sample inference', fontsize=fs, color='grey')

fig.subplots_adjust(top=0.9)
plt.savefig('rnnFigs/fig6B.pdf', format='pdf', bbox_inches='tight')

# %%




