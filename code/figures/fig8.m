%% fig8.m
% Figure 8 and Supplementary Tables 1-5 (individual differences, mediation).

% Running the whole script:
%   - draws every Figure 8 panel and keeps all figures open on screen
%   - prints every statistics table to the Command Window, in the same
%     layout as the Supplementary Tables
%   - stores every table in the struct "stats" (string tables, ready to copy)
%   - optionally writes all tables to an .xlsx file and a .txt log
%
% Sections
%   0. Settings
%   1. Load data and assemble per-subject variables
%   2. Fig 8A  - accuracy ~ model parameters            (Supp Table 1)
%   3. Fig 8A  - coefficients across sequence lengths   (Supp Table 2)
%   4. Fig 8B  - cognitive scores ~ model parameters     (Supp Table 3)
%   5. Supp Table 5 - personality ~ Big Five + age + sex
%   6. Supp Table 4 - mediation analyses
%   7. Save tables (optional)
%   Local functions

clear; clc; close all;
configALL;   % defines fs, chancecolor, guess, ...

%% 0. Settings ------------------------------------------------------------
SAVE_STATS   = false;              % true: write tables to xlsx + txt log
STATS_DIR    = './stats';
STATS_XLSX   = fullfile(STATS_DIR, 'Fig8_stats.xlsx');
STATS_LOG    = fullfile(STATS_DIR, 'Fig8_stats_log.txt');

CONDI        = 2;                  % task condition used throughout
ACC_SOURCE_B = 'human';            % accuracy used in Fig 8B / mediation:
                                   % 'human' | 'noisy_inferences' | 'noisy_responses'
NFCS_RESID_Z = 2.5;                % |Pearson residual| cut-off for NFCS outliers
MED_NBOOT    = 10000;              % bootstrap samples for the indirect effect
MED_ALPHA    = 0.05;
MED_HC       = 'HC3';              % robust SE type: 'none' | 'HC0' | 'HC1' | 'HC2' | 'HC3'
RNG_SEED     = 1;                  % makes bootstrap CIs reproducible

% plotting
msize     = 8;
edgecolor = 'w';
color     = guess;
star_props = struct('FontSize', 18, 'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', 'Color', color);

if SAVE_STATS
    if ~exist(STATS_DIR, 'dir'), mkdir(STATS_DIR); end
    if exist(STATS_LOG, 'file'), delete(STATS_LOG); end
    diary(STATS_LOG);
end
stats = struct();

%% 1. Load data and assemble per-subject variables -----------------------
load dat_bigtbl_COLINE.mat               % bigtbl
load dat_modeltbl_COLINE_full.mat        % modelout (noisy-inferences family)

% model codes in dat_modeltbl_COLINE_full: 4 = leak + noise, free theta; 5 = fixed theta
subjlist = unique(modelout.subj);        % 420 subjects
nsub     = numel(subjlist);
Mfull    = table2array(modelout);

parameter = nan(nsub, 5);                % [EoS, betac, betar, leak, noise]
acc1      = nan(nsub, 2, 4);             % [human; noisy inferences] x 4 lengths
score     = nan(nsub, 7);                % [Big5 (5), ICAR, NFCS]
sex       = nan(nsub, 1);
age       = nan(nsub, 1);

for s = 1:nsub
    sid  = subjlist(s);
    isS  = modelout.subj == sid & Mfull(:,2) == CONDI;
    iFree = isS & Mfull(:,3) == 4;       % leak + noise, free theta
    iFix  = isS & Mfull(:,3) == 5;       % theta fixed

    EoS  = Mfull(iFree,4) - Mfull(iFix,4);          % ELBO(free) - ELBO(fixed)
    parameter(s,:) = [EoS, Mfull(iFree,9), Mfull(iFree,10), Mfull(iFree,5), Mfull(iFree,7)];
    acc1(s,:,:)    = [Mfull(iFree,14:17); Mfull(iFree,18:21)];   % human; model

    ib = find(bigtbl.subj == sid);
    score(s,:) = [bigtbl.big5_domains(ib,:), bigtbl.icar_total(ib), bigtbl.nfcs_total(ib)];
    sex(s)     = bigtbl.female(ib);
    age(s)     = bigtbl.age(ib);
end
acc1 = cat(3, acc1, mean(acc1, 3));      % 5th "length" = mean over lengths

load dat_modeltbl_COLINE_exact-selnoise.mat   % modelout (noisy-responses family)
% model codes: 1 = free theta; 2 = fixed theta
subjlist2 = unique(modelout.subj);
assert(isequal(subjlist(:), subjlist2(:)), 'Subject lists differ between model files.');
Mexact = table2array(modelout);

parameter_exact = nan(nsub, 4);          % [EoS, betac, betar, selnoise]
acc2            = nan(nsub, 1, 4);
for s = 1:nsub
    sid   = subjlist(s);
    isS   = modelout.subj == sid & Mexact(:,2) == CONDI;
    iFree = isS & Mexact(:,3) == 1;
    iFix  = isS & Mexact(:,3) == 2;

    EoS = Mexact(iFree,4) - Mexact(iFix,4);
    parameter_exact(s,:) = [EoS, Mexact(iFree,9), Mexact(iFree,10), Mexact(iFree,14)];
    acc2(s,1,:)          = Mexact(iFree,19:22);
end
acc2 = cat(3, acc2, mean(acc2, 3));

% one entry per accuracy type: 1 human, 2 noisy inferences, 3 noisy responses
dvs        = cat(2, acc1, acc2);                         % nsub x 3 x 5
predictors = {parameter, parameter, parameter_exact};
typename   = {'human', 'noisy inferences', 'noisy responses'};
tabletitle = {'Human accuracy ~', ...
              'Full model (noisy-inferences model) predicted accuracy ~', ...
              'Control model (noisy-responses model) predicted accuracy ~'};

% regression specification for each accuracy type
spec(1).vars   = {'acc','EoS','betac','betar','leak','noise'};
spec(1).formula= 'acc ~ EoS + betac + betar + leak + noise';
spec(1).coefs  = {'EoS','betac','betar','leak','noise'};
spec(1).plot   = {'EoS','\beta_{c}','\beta_{r}','leak \delta','noise \sigma'};
spec(1).label  = {'EoS','beta_c','beta_r','leak delta','noise sigma'};
spec(2) = spec(1);
spec(3).vars   = {'acc','EoS','betac','betar','noise'};
spec(3).formula= 'acc ~ EoS + betac + betar + noise';
spec(3).coefs  = {'EoS','betac','betar','noise'};
spec(3).plot   = {'EoS','\beta_{c}','\beta_{r}','\sigma_{resp.}'};
spec(3).label  = {'EoS','beta_c','beta_r','sigma_resp'};

fprintf('Loaded %d subjects.\n', nsub);

%% 2. Fig 8A: accuracy ~ model parameters (mean over lengths) ------------
fprintf('\n=================== Supplementary Table 1 (accuracy) ===================\n');
for whichtype = 1:3
    sp   = spec(whichtype);
    Data = normalize([dvs(:,whichtype,end), predictors{whichtype}]);
    T    = array2table(Data, 'VariableNames', sp.vars);
    mdl  = fitlme(T, sp.formula);
    C    = getcoef(mdl, sp.coefs);

    stats.S1.(sprintf('acc_%s', strrep(typename{whichtype},' ','_'))) = ...
        print_coef_table(C, sp.label, ...
        sprintf('%s  (N = %d)', tabletitle{whichtype}, height(T)), 'Model component');

    % ---- figure: top tile = EoS, betac, betar; bottom tile = noise terms
    nk = numel(sp.coefs);
    figure('Name', sprintf('Fig8A coef - %s', typename{whichtype}), ...
           'Position', [420+200*whichtype, 300, 780/4, 464/2], 'Renderer', 'painters');
    tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile
    opt = coefplot_opts(color, edgecolor, chancecolor, msize, fs, star_props);
    opt.poffset = 0.02; opt.staryoff = 0.15;
    plot_coef_rows(C, 1:3, opt);
    title(typename{whichtype}, 'FontWeight', 'normal')
    set(gca, 'xtick', [-1 0 1]*0.3, 'xticklabel', {'-0.3','0','+0.3'}, ...
             'ytick', 1:nk, 'yticklabel', sp.plot)
    xlim([-1 1]*0.3); ylim([0.5 3.5])

    nexttile
    opt.poffset = 0.09; opt.staryoff = 0.1 - 0.05*(whichtype==3);
    plot_coef_rows(C, 4:nk, opt);
    set(gca, 'xtick', [-1 0 1], 'xticklabel', {'-1','0','+1'}, ...
             'ytick', 1:nk, 'yticklabel', sp.plot)
    xlabel('regression coef.')
    if whichtype < 3
        xlim([-1 1]);     ylim([3.5 5.5])
    else
        xlim([-1 1]*1.2); ylim([3.5 4.5])
    end
end

%% 3. Fig 8A: betac and EoS coefficients across sequence lengths ---------
lengths   = [8 12 16 20];
nlen      = numel(lengths);
reg_names = {'betac','EoS'};
reg_label = {'beta_c','EoS'};
reg_color = {color, color/1.8};
reg_shape = {'s','o'};
reg_size  = [8 7];
capsize   = [10 0];
off       = [-0.1 0.1];
o         = 0.3;

% fprintf('\n=========== Supplementary Table 1b (by sequence length) ===========\n');
fprintf('\n=========== Supplementary Table 2 (by sequence length) ===========\n');
for whichtype = 1:3
    sp = spec(whichtype);
    Beta = nan(2,nlen); Lo = Beta; Hi = Beta; P = Beta;
    rows = {};
    for L = 1:nlen
        Data = normalize([dvs(:,whichtype,L), predictors{whichtype}]);
        T    = array2table(Data, 'VariableNames', sp.vars);
        mdl  = fitlme(T, sp.formula);
        C    = getcoef(mdl, reg_names);
        Beta(:,L) = C.Estimate; Lo(:,L) = C.Lower; Hi(:,L) = C.Upper; P(:,L) = C.pValue;
        for r = 1:2
            rows(end+1,:) = {sprintf('%d', lengths(L)), reg_label{r}, ...
                fmtnum(C.Estimate(r),3), fmtnum(C.Lower(r),3), fmtnum(C.Upper(r),3), ...
                fmtnum(C.tStat(r),3), sprintf('%d', round(C.DF(r))), fmtp(C.pValue(r),3)}; 
        end
    end
    hdr = {'Length','Regressor','Mean coef.','95% CI lower','95% CI upper','t value','df','p value'};
    % stats.S1b.(sprintf('acc_%s', strrep(typename{whichtype},' ','_'))) = ...   (original)
    stats.S2.(sprintf('acc_%s', strrep(typename{whichtype},' ','_'))) = ...
        print_cell_table(sprintf('%s  [%s]  (N = %d; other regressors in model: %s)', ...
        tabletitle{whichtype}, 'by sequence length', height(T), strjoin(setdiff(sp.coefs, reg_names, 'stable'), ', ')), ...
        hdr, rows);

    % ---- figure
    figure('Name', sprintf('Fig8A length - %s', typename{whichtype}), ...
           'Position', [420+200*whichtype, 0, 780/4, 464/3.0], ...
           'Renderer', 'painters', 'PaperPositionMode', 'auto');
    tiledlayout(1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    nexttile; hold on
    plot([1-o, nlen+o], [0 0], '-', 'LineWidth', 1, 'Color', chancecolor);
    h = gobjects(1,2);
    for r = 1:2
        X = (1:nlen) + off(r);
        y = Beta(r,:); neg = y - Lo(r,:); pos = Hi(r,:) - y;
        h(r) = errorbar(X, y, neg, pos, reg_shape{r}, 'MarkerSize', reg_size(r), 'LineWidth', 1, ...
            'CapSize', capsize(r), 'MarkerFaceColor', reg_color{r}, 'Color', reg_color{r});
        plot(X, y, 'Color', reg_color{r}, 'LineWidth', 1)
        plot(X, y, reg_shape{r}, 'MarkerSize', reg_size(r)*1.2, 'LineWidth', 1, 'Color', edgecolor)
        for k = find(P(r,:) < 0.05)
            text(X(k), (y(k)+pos(k))*1.05, '*', 'FontSize', 14, 'Color', reg_color{r}, ...
                 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
        end
    end
    set(gca, 'box', 'off', 'color', 'none', 'LineWidth', 1, 'TickDir', 'out', 'FontSize', fs, ...
             'xtick', 1:nlen, 'xticklabel', arrayfun(@num2str, lengths, 'UniformOutput', false))
    xlim([1-o, nlen+o])
    xlabel('sequence length'); ylabel('regression coef.')
    if whichtype == 1
        legend(h, '\beta_{c}', 'EoS', 'box', 'off', 'location', 's');
    end
    yl = max(abs(ylim)); ylim([-1 1]*yl)
    set(gca, 'ytick', [-0.1 0 0.1], 'yticklabel', {'-0.1','0','+0.1'})
end

%% 4. Fig 8B: cognitive scores ~ model parameters -------------------------
% Exclude: missing/zero questionnaire scores, and the parameter outlier
% (subject beyond Tukey fences on all four of betac, betar, leak, noise).
isout_param = sum(isoutlier(parameter(:,2:5), 'quartiles'), 2) == 4;
badscore    = sum(score,2) == 0 | isnan(sum(score,2)) | isout_param;
fprintf('\nFig 8B exclusions: %d parameter outlier(s), %d missing/zero scores; N = %d.\n', ...
    sum(isout_param), sum(badscore & ~isout_param), sum(~badscore));

switch ACC_SOURCE_B
    case 'human',            acc_B = acc1(:,1,end);
    case 'noisy_inferences', acc_B = acc1(:,2,end);
    case 'noisy_responses',  acc_B = acc2(:,1,end);
    otherwise, error('Unknown ACC_SOURCE_B: %s', ACC_SOURCE_B);
end

var_score = {'Extrav','Agree','Consc','NegEmo','OpMind','ICAR','NFCS'};
var_param = {'EoS','betac','betar','leak','noise'};
var_covar = {'age','sex'};
varNames  = [{'acc'}, var_score, var_param, var_covar];
DataB     = normalize([acc_B(~badscore), score(~badscore,:), parameter(~badscore,:), ...
                       age(~badscore), sex(~badscore)]);
TB        = array2table(DataB, 'VariableNames', varNames);
score_valid = score(~badscore,:);
nB        = height(TB);

frm_param = 'EoS + betac + betar + leak + noise';
lab_param = {'EoS','beta_c','beta_r','leak delta','noise sigma'};

% NFCS: refit after removing large Pearson residuals (data not re-normalized)
mdl_nfcs_all = fitlme(TB, ['NFCS ~ ' frm_param]);
r_p          = residuals(mdl_nfcs_all, 'ResidualType', 'Pearson');
nfcs_out     = abs(r_p) > NFCS_RESID_Z;
mdl_nfcs     = fitlme(TB(~nfcs_out,:), ['NFCS ~ ' frm_param]);
mdl_icar     = fitlme(TB, ['ICAR ~ ' frm_param]);

% fprintf('\n=============== Supplementary Table 1 (cognitive scores) ===============\n');
fprintf('\n=============== Supplementary Table 3 (cognitive scores) ===============\n');
C_nfcs     = getcoef(mdl_nfcs, var_param);
C_nfcs_all = getcoef(mdl_nfcs_all, var_param);
C_icar     = getcoef(mdl_icar, var_param);
% stats.S1.NFCS_excl = print_coef_table(C_nfcs, lab_param, sprintf( ...   (original)
stats.S3.NFCS_excl = print_coef_table(C_nfcs, lab_param, sprintf( ...
    'NFCS ~  (N = %d; excluding %d outliers with |Pearson residual| > %.1f)', ...
    sum(~nfcs_out), sum(nfcs_out), NFCS_RESID_Z), 'Model component');
% stats.S1.NFCS_all  = print_coef_table(C_nfcs_all, lab_param, sprintf( ...   (original)
stats.S3.NFCS_all  = print_coef_table(C_nfcs_all, lab_param, sprintf( ...
    'NFCS ~  (N = %d; including the %d outliers)', nB, sum(nfcs_out)), 'Model component');
% stats.S1.ICAR      = print_coef_table(C_icar, lab_param, sprintf('ICAR ~  (N = %d)', nB), 'Model component');   (original)
stats.S3.ICAR      = print_coef_table(C_icar, lab_param, sprintf('ICAR ~  (N = %d)', nB), 'Model component');

% ---- figure: histograms + coefficient plots
figure('Name', 'Fig8B scores ~ parameters', 'Position', [431 398 450 356], ...
       'Renderer', 'painters', 'PaperPositionMode', 'auto');
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nb       = 17;
B_names  = {'NFCS','ICAR'};
B_scores = score_valid(:,[7 6]);
B_coefs  = {C_nfcs, C_icar};
B_color  = {[0.5 0.5 0.8], [0.8 0.5 0.2]};
plot_lab = {'EoS','\beta_c','\beta_r','leak \delta','noise \sigma'};
for k = 1:2
    nexttile
    edges = linspace(min(B_scores(:,k)), max(B_scores(:,k)), nb);
    histogram(B_scores(:,k), 'BinEdges', edges, 'FaceColor', B_color{k});
    set(gca, 'box', 'off', 'LineWidth', 1, 'TickDir', 'out', 'FontSize', fs, 'color', 'none')
    ylabel('count')
    title(B_names{k}, 'FontWeight', 'normal', 'Rotation', 10);

    nexttile
    opt = coefplot_opts(B_color{k}, edgecolor, chancecolor, msize, fs, star_props);
    opt.poffset = 0.05; opt.staryoff = 0.15; opt.starscale = 0.95;
    plot_coef_rows(B_coefs{k}, 1:5, opt);
    set(gca, 'xtick', [-0.3 0 0.3], 'xticklabel', {'-0.3','0','+0.3'}, ...
             'ytick', 1:5, 'yticklabel', plot_lab)
    xlabel('regression coefficient')
    xlim([-1 1]*0.35); ylim([0.5 5.5])
end

%% 5. Supp Table 5: personality ~ Big Five + age + sex --------------------
% fprintf('\n========================= Supplementary Table 3 =========================\n');
fprintf('\n========================= Supplementary Table 5 =========================\n');
frm_big5 = 'Extrav + Agree + Consc + NegEmo + OpMind + age + sex';
lab_big5 = {'Extrav','Agree','Consc','NegEmo','OpMind','age','sex'};
dv3      = {'NFCS','ICAR','EoS','betac'};
dv3_lab  = {'NFCS','ICAR','EoS','beta_c'};
for k = 1:numel(dv3)
    mdl = fitlme(TB, [dv3{k} ' ~ ' frm_big5]);
    C   = getcoef(mdl, lab_big5);
    % stats.S3.(dv3{k}) = print_coef_table(C, lab_big5, ...   (original)
    stats.S5.(dv3{k}) = print_coef_table(C, lab_big5, ...
        sprintf('%s ~  (N = %d)', dv3_lab{k}, height(TB)), 'Regressor');
end
fprintf(['Big-Five domains: Extrav = Extraversion, Agree = Agreeableness, Consc = Conscientiousness,\n' ...
         'NegEmo = Negative Emotionality, OpMind = Open-Mindedness.\n']);

%% 6. Supp Table 4: mediation analyses ------------------------------------
% fprintf('\n========================= Supplementary Table 2 =========================\n');
fprintf('\n========================= Supplementary Table 4 =========================\n');
ctrl = {'age','sex'};
med  = { % X       M        Y      label X   label M
        'NFCS',   'EoS',   'acc', 'NFCS',   'EoS';
        'EoS',    'NFCS',  'acc', 'EoS',    'NFCS';
        'ICAR',   'betac', 'acc', 'ICAR',   'beta_c';
        'betac',  'ICAR',  'acc', 'beta_c', 'ICAR'};
rng(RNG_SEED);
for k = 1:size(med,1)
    R = mediate_ols(TB, med{k,1}, med{k,2}, med{k,3}, ctrl, MED_NBOOT, MED_ALPHA, MED_HC);
    ttl = sprintf('%s to %s accuracy, mediator = %s, controls = {%s}  (N = %d; robust SE: %s; %d bootstraps)', ...
        med{k,4}, ACC_SOURCE_B, med{k,5}, strjoin(ctrl, ', '), R.n, MED_HC, MED_NBOOT);
    rows = cell(5, 6);
    for i = 1:5
        tstr = '';
        if ~isnan(R.t(i)), tstr = fmtnum(R.t(i), 2); end
        rows(i,:) = {R.path{i}, fmtnum(R.est(i),4), fmtnum(R.lo(i),4), fmtnum(R.hi(i),4), ...
                     tstr, fmtp(R.p(i),4)};
    end
    hdr = {'Path','Mean coef.','95% CI lower','95% CI upper','t value','p value'};
    % stats.S2.(sprintf('%s_via_%s', med{k,1}, med{k,2})) = print_cell_table(ttl, hdr, rows);   (original)
    stats.S4.(sprintf('%s_via_%s', med{k,1}, med{k,2})) = print_cell_table(ttl, hdr, rows);
end
fprintf(['Indirect a*b: percentile bootstrap CI; p = two-sided bootstrap proportion.\n' ...
         'All variables z-scored before fitting.\n']);

%% 7. Save tables (optional) ----------------------------------------------
if SAVE_STATS
    groups = fieldnames(stats);
    for g = 1:numel(groups)
        tbls = fieldnames(stats.(groups{g}));
        for t = 1:numel(tbls)
            sheet = sprintf('%s_%s', groups{g}, tbls{t});
            sheet = sheet(1:min(end,31));             % Excel limit
            writetable(stats.(groups{g}).(tbls{t}), STATS_XLSX, 'Sheet', sheet);
        end
    end
    diary off
    fprintf('\nTables written to %s\nLog written to %s\n', STATS_XLSX, STATS_LOG);
end

%% ======================== Local functions ==============================

function C = getcoef(mdl, names)
% Coefficients of a fitted model, picked BY NAME, in the order of "names".
cn = mdl.Coefficients;
nm = cellstr(cn.Name);
k  = zeros(numel(names),1);
for i = 1:numel(names)
    j = find(strcmp(nm, names{i}));
    assert(numel(j) == 1, 'Coefficient "%s" not found.', names{i});
    k(i) = j;
end
C = table(names(:), cn.Estimate(k), cn.Lower(k), cn.Upper(k), cn.tStat(k), ...
          cn.DF(k), cn.pValue(k), ...
          'VariableNames', {'Name','Estimate','Lower','Upper','tStat','DF','pValue'});
end

function opt = coefplot_opts(color, edgecolor, chancecolor, msize, fs, star_props)
opt = struct('color', color, 'edgecolor', edgecolor, 'chancecolor', chancecolor, ...
             'msize', msize, 'fs', fs, 'props', star_props, ...
             'poffset', 0.02, 'staryoff', 0.15, 'starscale', 1);
opt.props.Color = color;
end

function plot_coef_rows(C, rows, opt)
% Horizontal coefficient plot: CI line, dot, and * for p < .05.
hold on
plot([0 0], [0 height(C)+1], '-', 'LineWidth', 1, 'Color', opt.chancecolor)
for i = rows
    plot([C.Lower(i) C.Upper(i)], [i i], '-', 'LineWidth', 2, 'Color', opt.color);
    plot(C.Estimate(i), i, 'o', 'MarkerSize', opt.msize, 'MarkerFaceColor', opt.color, ...
         'LineWidth', 1, 'MarkerEdgeColor', opt.edgecolor);
    if C.pValue(i) < 0.05
        if C.Estimate(i) >= 0, xpos = C.Upper(i) + opt.poffset;
        else,                  xpos = C.Lower(i) - opt.poffset; end
        text(xpos*opt.starscale, i + opt.staryoff, '*', opt.props);
    end
end
set(gca, 'box', 'off', 'color', 'none', 'LineWidth', 1, 'TickDir', 'out', ...
         'FontSize', opt.fs, 'YDir', 'reverse', 'XTickLabelRotation', 0);
end

function out = print_coef_table(C, labels, ttl, firstcol)
% Supplementary-Table layout for one regression model.
df = unique(round(C.DF));
if isscalar(df), tcol = sprintf('t value (df = %d)', df); else, tcol = 't value'; end
rows = cell(height(C), 6);
for i = 1:height(C)
    rows(i,:) = {labels{i}, fmtnum(C.Estimate(i),3), fmtnum(C.Lower(i),3), ...
                 fmtnum(C.Upper(i),3), fmtnum(C.tStat(i),3), fmtp(C.pValue(i),3)};
end
hdr = {firstcol, 'Mean coef.', '95% CI lower', '95% CI upper', tcol, 'p value'};
out = print_cell_table(ttl, hdr, rows);
end

function out = print_cell_table(ttl, hdr, rows)
% Print a cell array of strings as an aligned text table; return it as a table.
w = cellfun(@length, [hdr; rows]);
w = max(w, [], 1) + 2;
fmt  = ['%-' num2str(w(1)) 's' sprintf('%%%ds', w(2:end)) '\n'];
rule = repmat('-', 1, sum(w));
fprintf('\n%s\n%s\n', ttl, rule);
fprintf(fmt, hdr{:});
fprintf('%s\n', rule);
for i = 1:size(rows,1), fprintf(fmt, rows{i,:}); end
fprintf('%s\n', rule);
vn  = matlab.lang.makeValidName(hdr);
vn  = matlab.lang.makeUniqueStrings(vn);
out = cell2table(rows, 'VariableNames', vn);
out.Properties.Description = ttl;
end

function s = fmtnum(x, d)
% Fixed decimals; very small non-zero values keep 2 significant digits.
if isnan(x), s = ''; return; end
if x ~= 0 && abs(x) < 10^(-d)
    s = sprintf('%.2g', x);
else
    s = sprintf(['%.' num2str(d) 'f'], x);
    if all(s == '0' | s == '.' | s == '-'), s = strrep(s, '-', ''); end   % no "-0.000"
end
end

% function s = fmtp(p, dsig)   (original)
function s = fmtp(p, ~)
% p-value as in the Supplementary Tables; "*" marks p < .05.
% APA: exact P to 3 decimals, "< 0.001" below 0.001 (leading zero kept, NHB style).
% The second input (decimals) is no longer used.
% if p < 1e-4,      s = '< 0.0001';
% elseif p < 1e-3,  s = '< 0.001';
% elseif p < 0.01,  s = '< 0.01';
% elseif p < 0.05
% if p < 1e-3,      s = '< 0.001';   % exact P unless P < 0.001
% elseif p < 0.05
%     s = sprintf(['%.' num2str(dsig) 'f'], p);
%     if str2double(s) >= 0.05, s = sprintf('%.4f', p); end
% else
%     s = sprintf('%.3f', p);
% end
if p < 1e-3
    s = '< 0.001';
else
    s = sprintf('%.3f', p);
end
if p < 0.05, s = [s '*']; end
end

function R = mediate_ols(T, X, M, Y, ctrl, nboot, alpha, hc)
% Single-mediator model with covariates (OLS).
%   a       : M ~ X + ctrl
%   b, c'   : Y ~ X + M + ctrl
%   total c : Y ~ X + ctrl
%   indirect: a*b, percentile bootstrap CI and two-sided bootstrap p.
x = T.(X); m = T.(M); y = T.(Y); Cv = T{:, ctrl};
n = numel(y);
Za = [ones(n,1) x Cv];
Zb = [ones(n,1) x m Cv];
[ba, sea, dfa] = ols_robust(Za, m, hc);
[bb, seb, dfb] = ols_robust(Zb, y, hc);
[bc, sec, dfc] = ols_robust(Za, y, hc);       % total effect uses the same design as a

est = [ba(2); bb(3); bb(2); bc(2)];
se  = [sea(2); seb(3); seb(2); sec(2)];
df  = [dfa; dfb; dfb; dfc];
t   = est ./ se;
p   = 2 * tcdf(-abs(t), df);
tc  = tinv(1 - alpha/2, df);
lo  = est - tc.*se;
hi  = est + tc.*se;

ab  = ba(2) * bb(3);
abb = nan(nboot, 1);
for k = 1:nboot
    ii  = randi(n, n, 1);
    a_k = Za(ii,:) \ m(ii);
    b_k = Zb(ii,:) \ y(ii);
    abb(k) = a_k(2) * b_k(3);
end
ci  = prctile(abb, 100*[alpha/2, 1 - alpha/2]);
pab = min(1, 2 * min(mean(abb <= 0), mean(abb >= 0)));

R.path = {'a'; 'b'; 'direct c'''; 'total'; 'indirect a*b'};
R.est  = [est; ab];
R.lo   = [lo; ci(1)];
R.hi   = [hi; ci(2)];
R.t    = [t; NaN];
R.p    = [p; pab];
R.n    = n;
end

function [b, se, df] = ols_robust(Z, y, hc)
% OLS with classical or heteroskedasticity-consistent (HC0-HC3) SEs.
[n, k] = size(Z);
b   = Z \ y;
e   = y - Z*b;
df  = n - k;
XtXi = inv(Z'*Z);
switch upper(hc)
    case 'NONE'
        V = XtXi * (e'*e) / df;
    otherwise
        h = sum((Z*XtXi) .* Z, 2);            % leverages
        switch upper(hc)
            case 'HC0', w = e.^2;
            case 'HC1', w = e.^2 * n/df;
            case 'HC2', w = e.^2 ./ (1-h);
            case 'HC3', w = e.^2 ./ (1-h).^2;
            otherwise, error('Unknown HC type: %s', hc);
        end
        V = XtXi * (Z' * (Z .* w)) * XtXi;
end
se = sqrt(diag(V));
end
