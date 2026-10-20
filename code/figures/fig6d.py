#%%
import torch
import pickle
import numpy as np
import matplotlib
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D  
from pathlib import Path
from scipy.stats import zscore
from sklearn.linear_model import LinearRegression
from sklearn.metrics import r2_score

matplotlib.use("QtAgg")
import seaborn as sns
colors = sns.color_palette('colorblind')
colors = [colors[2], colors[3], colors[9], colors[6]]

# load key modules and functions
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
)

SEED = 1234
np.random.seed(SEED)
torch.manual_seed(SEED)
rng = np.random.default_rng(SEED)

def center_per_condition(scores_t, cond_bits):
    """
    scores_t: [n_games, k] PC scores at time t
    cond_bits: [n_games, 2] 0/1 bits per game
    returns scores with each condition's mean removed
    """
    X = scores_t.copy()
    b1 = cond_bits[:, 0].astype(int)
    b2 = cond_bits[:, 1].astype(int)
    cond_id = (b1 << 1) | b2
    for cid in np.unique(cond_id):
        idx = (cond_id == cid)
        X[idx] -= X[idx].mean(axis=0, keepdims=True)
    return X

def effective_dim(X):
    """
    Participation ratio D_eff without centering.
    X: 2D array [samples x features]. No mean subtraction.
    """
    X = np.asarray(X, dtype=np.float64)
    s = np.linalg.svd(X, full_matrices=False, compute_uv=False)  # singular values
    lam = s**2
    denom = np.sum(lam**2)
    if denom <= 1e-12:
        return np.nan
    return (lam.sum()**2) / denom

def procrustes_centered_translation(X, Y):
    """
    Align X to Y with an orthogonal rotation estimated on centered copies,
    then apply rotation plus translation to the original (uncentered) X.
    Shapes: X, Y -> [nSamples, nUnits]. Returns X_aligned, R, t.
    """
    mx = X.mean(axis=0, keepdims=True)
    my = Y.mean(axis=0, keepdims=True)
    Xc = X - mx
    Yc = Y - my
    M = Xc.T @ Yc
    U, _, Vt = np.linalg.svd(M, full_matrices=False)
    R = U @ Vt
    # optional: forbid reflections
    if np.linalg.det(R) < 0:
        Vt[-1, :] *= -1
        R = U @ Vt
    t = my - mx @ R
    X_aligned = X @ R + t
    return X_aligned, R, t

def pca_no_center(X, k=3):
    """PCA via SVD with no centering. Returns components and scores."""
    U, S, Vt = np.linalg.svd(X, full_matrices=False)
    comps  = Vt.T[:, :k]                  # [nUnits, k]
    scores = (U[:, :k] * S[:k])           # [nSamples, k]
    return comps, scores

device = torch.device("cpu")
base_dir = ROOT / "code" / "rnn" / "saved_runs"

# Parameters
loss_functions = {
    "bandit": ["pGrad"],
    "guess": ["xEntro", "hybrid"],
}
target_colors = {
    "bandit": ["ora", "blu"], # target color for bandit
    "guess": ["non"],
}

nsub = 25
ref_instance = 1
subjects = np.arange(1, nsub+1)
test_noise_set = [0.0]
n_trials = 30
n_games = 1000
sequence_lengths = [n_trials]
conditions = [(0, 0), (0, 1), (1, 0), (1, 1)]

input_tensor_opt1, input_tensor_opt2, target = generate_sequences(n_trials, n_games, conditions, rng=rng)
input_tensors = make_input_tensor(input_tensor_opt1, input_tensor_opt2)

# Step 1: collect hidden states
D_eff = np.full((nsub, 4), np.nan)
D_eff_traj = np.full((4, nsub, len(test_noise_set), n_trials+1), np.nan)
H_store = np.full((4, nsub, len(test_noise_set), n_trials+1, n_games, 64), np.nan)
choice_store = np.full((4, nsub, len(test_noise_set), n_trials, n_games), np.nan)
c_store = np.full((4, nsub, len(test_noise_set), n_trials+1, n_games), np.nan)
v_store = np.full((4, nsub, len(test_noise_set), n_trials+1, n_games), np.nan)
cboth_store = np.full((4, nsub, len(test_noise_set), n_trials+1, n_games, 2), np.nan)

subj_i = -1
for subj in subjects:
    subj_i += 1
    for noise_i, test_noise_value in enumerate(test_noise_set):
        network_i = -1
        for task, losses in loss_functions.items():
            for loss in losses:
                for color in target_colors[task]:
                    network_i += 1
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

                    checkpoint = torch.load(fpath, map_location=device)
                    model_kwargs = checkpoint["model_kwargs"]
                    state_dict = checkpoint["state_dict"]
                    model_kwargs["noise_value"] = test_noise_value
                    model = CustomRNN(**model_kwargs)
                    model.load_state_dict(state_dict)
                    model.to(device)
                    model.eval()

                    targetcolor = 0
                    if color=='blu':
                        targetcolor = -1
                    elif color=='ora':
                        targetcolor = +1
                    
                    with torch.no_grad():
                        output = run_traineval_loop(input_tensors, model, device)

                    H = output["h_activat"] # H[0] = after 1st sample
                    c_min = output['certainty_min']
                    c_store[network_i, subj_i, noise_i] = c_min.detach().cpu().numpy() # start from 0

                    S = output['states'] # [trials, games, 2options]
                    S_ex = output['states_ex']
                    S = torch.cat([S, S_ex.unsqueeze(0)], dim=0) # S[0] = 0, before 1st sample
                    cboth_store[network_i, subj_i, noise_i] = S.abs()

                    S_targetAligned = S*targetcolor
                    # Best target-likeness at each time x game
                    TL_best = S_targetAligned.max(dim=2).values    # shape [trials+1, games]
                    v_diff = S_targetAligned[:,:,0] - S_targetAligned[:,:,1]
                    v_store[network_i, subj_i, noise_i] = v_diff.detach().cpu().numpy()

                    choice_store[network_i, subj_i, noise_i] = output['chosen_actions']

                    hidden_dim = model_kwargs['hidden_dim']
                    if H.shape[1] == hidden_dim and H.shape[-1] == n_trials:
                        H = H.permute(2, 0, 1).contiguous()
                    elif H.shape[-1] == hidden_dim:
                        pass
                    else:
                        raise ValueError(f"Unexpected shape {H.shape}")

                    T, G, Hdim = H.shape
                    init_state = torch.zeros(1, G, Hdim, device=H.device, dtype=H.dtype)
                    H = torch.cat([init_state, H], dim=0) # [time, games, units], now H[0] = 0
                    H_store[network_i, subj_i, noise_i] = H.detach().cpu().numpy()

                    H_traj = H[:,:,:]
                    for t in range(n_trials+1):
                        D_eff_traj[network_i, subj_i, noise_i, t] = effective_dim(H_traj[t])

target_store = target.detach().cpu().numpy()

#%
plt.close('all')
from sklearn.model_selection import KFold
from sklearn.linear_model import LinearRegression
from sklearn.metrics import r2_score

k = 4

nType, nInstance, nNoise, nTime, nGames, nUnits = H_store.shape
assert nNoise == 1, "nNoise must be 1"

# map each game to a condition index 0..3 in the order above
cond_id = (2*target_store[:,0] + target_store[:,1]).astype(int)  # 0:[0,0], 1:[0,1], 2:[1,0], 3:[1,1]

plt.close('all')

pc_cert_corr_all = np.full((nInstance, nType, nTime-1, k), np.nan, dtype=float)
pc_cert_r2_oof = np.full((nInstance, nType, nTime-1, k), np.nan, dtype=float)

state_traj_all = np.full((4, 4, n_trials+1, k), np.nan)
EFF_dim = np.full((nInstance, nType), np.nan)
for t in range(nType):

    # reference instance for this type
    Href = H_store[t, ref_instance, 0]                  # [nTime, nGames, nUnits]
    Xref = Href.reshape(nTime*nGames, nUnits).astype(np.float32, copy=False)

    # align every instance to the reference (centered Procrustes with translation)
    X_aligned = []
    for j in range(nInstance):
        Hj = H_store[t, j, 0]                           # [nTime, nGames, nUnits]
        Xj = Hj.reshape(nTime*nGames, nUnits).astype(np.float32, copy=False)
        Xj_aligned, Rj, tj = procrustes_centered_translation(Xj, Xref)
        X_aligned.append(Xj_aligned)

    # shared PCA for this type on concatenated aligned data (no centering)
    Xcat = np.vstack(X_aligned)                         # [(nInstance*nTime*nGames), nUnits]
    comps, _ = pca_no_center(Xcat, k=k)
    comps[:, 2] *= -1

    # Per-instance effective dimension at time t
    eff = np.empty(len(X_aligned))
    for i, Xi in enumerate(X_aligned):           # Xi: [(nTime*nGames), nUnits] for instance i
        # Option A: if effective_dim is rotation-invariant (preferred, simpler)
        eff[i] = effective_dim(Xi)

    EFF_dim[:len(eff), t] = eff

    # CHANGED: keep per-instance scores for decoding
    scores_all = np.zeros((nInstance, nTime, nGames, k), dtype=np.float32)
    for j in range(nInstance):
        Sj = (X_aligned[j] @ comps).reshape(nTime, nGames, k)
        scores_all[j] = Sj
    
    nI, nT, nG, k = scores_all.shape  # nT == nTime

    for i in range(nI):
        for tt in range(1, 21):
            tsave = tt-1
            X = scores_all[i, tt, :, :]          # [nG, k]
            y = c_store[t, i, 0, tt, :]
            # y = cboth_store[t, i, 0, tt, :, 1]

            # center
            Xc = X - X.mean(axis=0, keepdims=True)
            yc = y - y.mean()

            # Pearson r for all PCs at once
            num = (Xc * yc[:, None]).sum(axis=0)                 # [k]
            den = np.sqrt((Xc**2).sum(axis=0) * (yc**2).sum())   # [k]
            pc_cert_corr_all[i, t, tsave, :] = num / den

            # ---- Per-instance OOF linear decoding across games ----
            # mask = np.isfinite(X).all(axis=1) & np.isfinite(y)
            # X = X[mask]; y = y[mask]
            
            # if len(y) >= 10 and X.shape[1] >= 1:   # simple guard
            for pc_i in range(k):
                X_i = X[:,[pc_i]]
                kf = KFold(n_splits=10, shuffle=True, random_state=0)
                y_pred = np.empty_like(y); y_pred[:] = np.nan
                for tr, te in kf.split(X_i):
                    Xtr, Xte = X_i[tr], X_i[te]
                    ytr = y[tr]

                    # fold-wise standardization to prevent leakage
                    Xmu = Xtr.mean(axis=0, keepdims=True)
                    Xsd = Xtr.std(axis=0, keepdims=True); Xsd[Xsd == 0] = 1.0
                    Xtrn = (Xtr - Xmu) / Xsd
                    Xten = (Xte - Xmu) / Xsd

                    ymu = ytr.mean(); ysd = ytr.std(); ysd = 1.0 if ysd == 0 else ysd
                    ytrn = (ytr - ymu) / ysd

                    reg = LinearRegression().fit(Xtrn, ytrn)
                    y_pred[te] = reg.predict(Xten) * ysd + ymu

                pc_cert_r2_oof[i, t, tsave, pc_i] = r2_score(y, y_pred)
                # np.corrcoef(y, y_pred)[0, 1]
                # r2_score(y, y_pred)

    # project each instance, then average in PC space
    scores_mean = np.zeros((nTime, nGames, k), dtype=np.float32)
    for j in range(nInstance):
        Sj = (X_aligned[j] @ comps).reshape(nTime, nGames, k)
        scores_mean += Sj
    scores_mean /= nInstance                            # [nTime, nGames, k]

    # average by condition to get one trajectory per condition
    traj = np.zeros((4, nTime, k), dtype=np.float32)
    for c in range(4):
        idx = np.where(cond_id == c)[0]
        traj[c] = scores_mean[:, idx, :].mean(axis=1)   # [nTime, k]

    state_traj_all[t] = traj

#%

plt.close('all')
import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D  # noqa: F401  # ensures 3D projection is registered

# --- figure & style ---
mpl.rcParams['font.family'] = 'Helvetica'
fs = 12
mpl.rcParams.update({
    'font.size': fs,
    'axes.titlesize': fs,
    'axes.labelsize': fs,
    'xtick.labelsize': fs,
    'ytick.labelsize': fs,
    'legend.fontsize': fs,
})

# Expect: state_traj_all shape (nType=4, nCond=4, nTime, k=3)

# shared limits across all panels
pts = state_traj_all.reshape(-1, state_traj_all.shape[-1])
pts = pts[np.isfinite(pts).all(axis=1)]
if k==4:
    xmin, ymin, zmin,_ = pts.min(axis=0)
    xmax, ymax, zmax,_ = pts.max(axis=0)
elif k==3:
    xmin, ymin, zmin = pts.min(axis=0)
    xmax, ymax, zmax = pts.max(axis=0)

# defaults if you haven't defined them
conditions = ['[0,0]', '[0,1]', '[1,0]', '[1,1]']

# build a 2x4 grid; bottom row will be 3D axes
fig = plt.figure(figsize=(9, 3), constrained_layout=True)
gs = fig.add_gridspec(1, 4, wspace=0.0, hspace=0.0)

# top row placeholders (optional): keep as 2D empty panels for now
# top_axes = [fig.add_subplot(gs[0,i]) for i in range(4)]
# for ax in top_axes:
#     ax.axis('off')  # or put whatever you plan later

# bottom row: 3D hidden-state trajectories
titles_hidden = ['match (choose orange)', 'match (choose blue)', 'guess (state only)', 'guess (state + meta)']
bottom_axes = [fig.add_subplot(gs[0, i], projection='3d') for i in range(4)]

for panel_idx, ax in enumerate(bottom_axes):
    # ax.set_title(titles_hidden[panel_idx], fontsize=fs)

    # type index for this panel
    i = panel_idx
    state_traj_first = state_traj_all[i]   # [nCond=4, nTime, 3]

    # plot each condition trajectory
    for j, cond in enumerate(conditions):
        traj = state_traj_first[j]         # [nTime, 3]
        if not np.isfinite(traj).all():
            # skip if this condition is missing for this type
            continue
        x, y, z = traj[:, 0], traj[:, 1], traj[:, 2]
        ax.plot(x, y, z, color=colors[j], linewidth=1.8, label=str(cond))

    # optional milestone markers
        trial_ids = [idx for idx in [8, 12, 16, 20] if idx < len(x)]
        if trial_ids:
            ax.scatter(x[trial_ids], y[trial_ids], z[trial_ids],
                       s=np.linspace(10, 80, len(trial_ids)),
                       color=colors[j], edgecolor='k', linewidth=0.5, alpha=0.6)

    # cosmetics and shared limits
    ax.grid(False)
    # if i==3:
        # ax.set_xlabel('PC1'); ax.set_ylabel('PC2'); ax.set_zlabel('PC3')
    ax.set_xlim(xmin, xmax); ax.set_ylim(ymin, ymax); ax.set_zlim(zmin, zmax)

    ax.xaxis.labelpad = 0
    ax.yaxis.labelpad = 0
    ax.zaxis.labelpad = 0
    ax.tick_params(pad=0, labelsize=fs)
    # ax.view_init(elev=30, azim=-30)
    # ax.view_init(30, -80)
    ax.set_box_aspect((1, 1, 0.8))
    if i<3:
        ax.set_xticks([])
        ax.set_yticks([])
        ax.set_zticks([])

    # unique legend
    h, l = ax.get_legend_handles_labels()
    uniq = dict(zip(l, h))
    # if uniq:
        # ax.legend(uniq.values(), uniq.keys(), frameon=False, loc='upper left', fontsize=8)

plt.tight_layout()
plt.show(block=False)

import os
os.makedirs('rnnFigs', exist_ok=True)
plt.savefig('rnnFigs/fig_hiddenPCA.pdf', format='pdf', bbox_inches='tight')

#%%
plt.close('all')

# Select the two guess nets (indices 2 and 3)
idx_nets = [2, 3]
col_titles = [titles_hidden[i] for i in idx_nets]

# Slice arrays
corr_arr = pc_cert_corr_all[:, idx_nets, ...]  # (nI, 2, Tm1, k)
r2_arr   = pc_cert_r2_oof[:, idx_nets, ...]    # (nI, 2, Tm1[, k])

# Parse shapes
nI, nNet = corr_arr.shape[:2]
Tm1      = corr_arr.shape[2]
k_corr   = corr_arr.shape[3]
has_pc_in_r2 = (r2_arr.ndim == 4)
k_r2     = r2_arr.shape[3] if has_pc_in_r2 else 1

# Stats
corr_mean = np.nanmean(corr_arr, axis=0)                       # (2, Tm1, k_corr)
corr_sem  = np.nanstd(corr_arr, axis=0, ddof=1)/np.sqrt(nI)    # (2, Tm1, k_corr)

if has_pc_in_r2:
    r2_mean = np.nanmean(r2_arr, axis=0)                       # (2, Tm1, k_r2)
    r2_sem  = np.nanstd(r2_arr, axis=0, ddof=1)/np.sqrt(nI)    # (2, Tm1, k_r2)
else:
    r2_mean = np.nanmean(r2_arr, axis=0)                       # (2, Tm1)
    r2_sem  = np.nanstd(r2_arr, axis=0, ddof=1)/np.sqrt(nI)    # (2, Tm1)

# Figure
fig, axs = plt.subplots(2, nNet, figsize=(8, 5), sharex=True, sharey=False)
x = np.arange(Tm1)
xtick = [0, 9, 19]; xtlbl = [1, 10, 20]

pc_labels_corr = [f'PC{p+1}' for p in range(k_corr)]
pc_labels_r2   = [f'PC{p+1}' for p in range(k_r2)] if has_pc_in_r2 else ['OOF R²']

# Top row: Pearson r per PC
for col in range(nNet):
    ax = axs[0, col]
    for p in range(k_corr):
        m = corr_mean[col, :, p]; s = corr_sem[col, :, p]
        ax.plot(x, m, lw=2, label=pc_labels_corr[p] if col == 0 else "_nolegend_")
        ax.fill_between(x, m - s, m + s, alpha=0.2, linewidth=0)
    ax.set_title(col_titles[col])
    ax.set_ylim([-1, 1])
    ax.set_xticks(xtick); ax.set_xticklabels(xtlbl)
    if col == 0:
        ax.set_ylabel('Pearson r (PC vs certainty)')
    ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)

# Bottom row: OOF decoding
for col in range(nNet):
    ax = axs[1, col]
    if has_pc_in_r2:
        for p in range(k_r2):
            m = r2_mean[col, :, p]; s = r2_sem[col, :, p]
            ax.plot(x, m, lw=2, label=pc_labels_r2[p] if col == 0 else "_nolegend_")
            ax.fill_between(x, m - s, m + s, alpha=0.2, linewidth=0)
    else:
        m = r2_mean[col, :]; s = r2_sem[col, :]
        ax.plot(x, m, lw=2, label=pc_labels_r2[0] if col == 0 else "_nolegend_")
        ax.fill_between(x, m - s, m + s, alpha=0.2, linewidth=0)

    ax.set_xticks(xtick); ax.set_xticklabels(xtlbl)
    if col == 0:
        ax.set_ylabel('10-fold cross-val. R²')
    ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
    ax.set_xlabel('sampling trial')
    ax.set_ylim([-0.01,1])

# Legends: only once
h0, l0 = axs[0,0].get_legend_handles_labels()
if h0:
    fig.legend(h0, l0, loc='upper center', ncol=max(len(h0), 1), frameon=False)

plt.tight_layout(rect=(0, 0, 1, 0.92))
plt.show(block=False)


plt.savefig('rnnFigs/fig_hiddenPCA_decoding.pdf', format='pdf', bbox_inches='tight')
#%%

from itertools import combinations

# Expect: state_traj_all shape = (nType, nCond, nTime, k)
nType, nCond, nTime, k = state_traj_all.shape

# choose last two networks
idx_nets = [nType - 2, nType - 1]
row_titles = [titles_hidden[i] for i in idx_nets]

# pick PC pairs: if k>=4 use top-4 PCs like your example, else all pairs
pcs_to_use = list(range(min(k, 4)))
pc_pairs = list(combinations(pcs_to_use, 2))
n_pairs = len(pc_pairs)

# figure
plt.close('all')
fig, axs = plt.subplots(2, n_pairs, figsize=(2.2 * n_pairs, 5.0), sharex=False, sharey=False)

# ensure axs is 2D
if n_pairs == 1:
    axs = np.array([[axs[0]], [axs[1]]])

# convert milestone trial numbers (1-based in your note) to 0-based indices
milestones_1based = [8, 12, 16, 20]
def milestone_idx(nT):
    return [t-1 for t in milestones_1based if (t-1) >= 0 and (t-1) < nT]

ms_idx = milestone_idx(nTime)

# colors and conditions (define if not already)
if 'conditions' not in globals():
    conditions = ['[0,0]', '[0,1]', '[1,0]', '[1,1]']
# if 'colors' not in globals():
#     tab10 = plt.get_cmap('tab10')
#     colors = [tab10(i) for i in range(nCond)]

for r, net_i in enumerate(idx_nets):
    # data for this network: [nCond, nTime, k]
    traj_all = state_traj_all[net_i]

    for c, (p1, p2) in enumerate(pc_pairs):
        ax = axs[r, c]

        # collect mins/maxs for shared limits per subplot
        xs_all, ys_all = [], []

        for j, cond in enumerate(conditions):
            traj = traj_all[j]  # [nTime, k]
            if not np.isfinite(traj).all():
                continue

            x = traj[:, p1]
            y = traj[:, p2]
            ax.plot(x, y, linewidth=1.8, color=colors[j], label=str(cond))

            if ms_idx:
                ax.scatter(x[ms_idx], y[ms_idx],
                           s=np.linspace(10, 80, len(ms_idx)),
                           color=colors[j], edgecolor='k', linewidth=0.5, alpha=0.6)

            xs_all.append(x); ys_all.append(y)

        # axis cosmetics
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.set_xlabel(f'PC{p1+1}')
        ax.set_ylabel(f'PC{p2+1}')

        # per-subplot limits with small padding
        if xs_all:
            xcat = np.concatenate(xs_all); ycat = np.concatenate(ys_all)
            xpad = 0.05 * (np.nanmax(xcat) - np.nanmin(xcat) + 1e-12)
            ypad = 0.05 * (np.nanmax(ycat) - np.nanmin(ycat) + 1e-12)
            ax.set_xlim(np.nanmin(xcat) - xpad, np.nanmax(xcat) + xpad)
            ax.set_ylim(np.nanmin(ycat) - ypad, np.nanmax(ycat) + ypad)

            ax.set_xlim(-5, 5)
            ax.set_ylim(-5, 5)
            ax.set_xticks([-5, 0, 5])
            ax.set_yticks([-5, 0, 5])

        # column titles show PC pair
        if r == 0:
            ax.set_title(f'PC{p1+1} vs PC{p2+1}')

        # row labels as suptitles on the leftmost plots
        if c == 0:
            ax.text(-.5, 0.5, row_titles[r],
                    transform=ax.transAxes, rotation=90,
                    va='center', ha='right', fontsize=12)

# one shared legend
handles, labels = axs[0, 0].get_legend_handles_labels()
if handles:
    fig.legend(handles, labels, loc='upper center', ncol=nCond, frameon=False)

plt.tight_layout(rect=(0, 0, 1, 0.92))
plt.show(block=False)

plt.savefig('rnnFigs/fig_hiddenPCA_comb.pdf', format='pdf', bbox_inches='tight')

means = np.full(nType, np.nan)
mins  = np.full(nType, np.nan)
maxs  = np.full(nType, np.nan)

for t in range(nType):
    col = EFF_dim[:, t]
    if np.isnan(col).all():
        continue
    means[t] = np.nanmean(col)
    mins[t]  = np.nanmin(col)
    maxs[t]  = np.nanmax(col)

# print per type
names = titles_hidden if 'titles_hidden' in globals() and len(titles_hidden) == nType else [f'Net {t}' for t in range(nType)]
for t in range(nType):
    if np.isnan(means[t]):
        print(f'{names[t]}: no data')
    else:
        print(f'{names[t]}: mean={means[t]:.3f} [{mins[t]:.3f}, {maxs[t]:.3f}]')
