function run_fit_comleak_splithalf(subjID,type,dataset)

    subjID = str2double(subjID);
    condlist = 2;

    % Load data
    load(['dat_choicestbl_',dataset,'.mat'],'choicestbl');
    choicestbl(choicestbl.excludepart == true,:) = [];

    % Define subject
    subjlist = unique(choicestbl.subj);
    
    if subjID < 1 || subjID > numel(subjlist)
        error('subjID index %d is outside the valid range 1-%d.', subjID,numel(subjlist));
    end
    
    subjlist = subjlist(subjID);

    % Define list of fits
    [icond_fit,isubj_fit] = ndgrid(condlist,subjlist);
    isubj_fit = isubj_fit(:);
    icond_fit = icond_fit(:);

    % Fit each subject-condition combination
    nfit = numel(isubj_fit);

    for ifit = 1:nfit
        fun_fit_modelbound_noisyleaky_splithalf(choicestbl, isubj_fit(ifit), icond_fit(ifit), dataset, type);
    end

end


%% Fit odd and even sequence halves separately
function fun_fit_modelbound_noisyleaky_splithalf(data,isubj,icond,dataset,type)

if nargin < 5
    error('Missing input arguments!');
end

% Output directory
foldname = ['./fit_splithalf_',dataset];

if ~exist(foldname,'dir')
    mkdir(foldname);
end

% Add BADS/VBMC toolboxes to path
addpath(genpath(fullfile(fileparts(mfilename('fullpath')),'..','utils','toolbox')));

% Find all sequences for this subject and condition
iseq_all = find(data.subj == isubj & data.condition == icond);

if isempty(iseq_all)
    error('No data found for subject %d, condition %d.',isubj,icond);
end

% Split according to sequence order within this subject-condition subset
half_names   = {'odd','even'};
half_indices = {1:2:numel(iseq_all), 2:2:numel(iseq_all)};

for ihalf = 1:2

    halfname = half_names{ihalf};

    % Select odd- or even-numbered sequences
    iseq = iseq_all(half_indices{ihalf});

    if isempty(iseq)
        warning(['Skipping subject %d, condition %d, %s half: ', ...
                 'no sequences available.'], ...
                 isubj,icond,halfname);
        continue;
    end

    fprintf(['Fitting subject %d, condition %d, %s half ', ...
             '(%d sequences).\n'], ...
             isubj,icond,halfname,numel(iseq));

    % Set output filename
    filename = sprintf( ...
        '%s_fit_model_%s_isubj%03d_icond%d_half%s.mat', ...
        dataset,type,isubj,icond,halfname);

    % Extract data for the selected half
    conditn = data.condition(iseq);
    targetc = (2*data.targetcolor(iseq)-3).*(conditn ~= 2);
    colvals = data.colorseen(iseq);
    choices = data.choices(iseq);
    nsample = data.nsamples(iseq);

    % Remove NaN padding
    nseq = numel(choices);

    for jseq = 1:nseq
        colvals{jseq} = colvals{jseq}(:,1:nsample(jseq));
        choices{jseq} = choices{jseq}(1:nsample(jseq));
    end

    % Remove sequences containing missing choices
    isbad = cellfun(@(x) any(isnan(x)),choices);

    targetc(isbad) = [];
    colvals(isbad) = [];
    choices(isbad) = [];

    if isempty(choices)
        warning(['Skipping subject %d, condition %d, %s half: ', ...
                 'all selected sequences contain missing choices.'], ...
                 isubj,icond,halfname);
        continue;
    end

    % Create configuration structure
    cfg = struct();

    cfg.conditn = icond;
    cfg.targetc = targetc;
    cfg.colvals = colvals;
    cfg.choices = choices;

    cfg.gamma   = 0.1;

    cfg.fitalgo = 'bads';
    cfg.noprior = 1;
    cfg.npft    = 1000;
    cfg.nres    = 100;
    cfg.verbose = 2;

    switch type
        case 'exact'
            cfg.delta = 0;
            cfg.sigma = 0;
            cfg.npft  = 2;
            cfg.nres  = 2;

        case 'comleak'
            cfg.sigma = 0;
            cfg.npft  = 2;
            cfg.nres  = 2;

        case 'noise'
            cfg.delta = 0;

        case 'comleaknoise'
            % Fit all parameters

        case 'comleakpre'
            cfg.sigma    = 0;
            cfg.npft     = 2;
            cfg.nres     = 2;
            cfg.leakrule = 'pre';

        case 'comleaknoisepre'
            cfg.leakrule = 'pre';

        case 'comleaknoiseNOthres'
            cfg.theta = 0;

        case 'noiseNOthres'
            cfg.delta = 0;
            cfg.theta = 0;

        otherwise
            error('Wrong model type: %s',type);
    end

    % BADS fitting
    cfg.nrun = 10;
    out_bads = fit_modelbound_noisyleaky_comleak(cfg);

    % Use BADS estimates to initialize VBMC
    cfg.pini.betav = out_bads.betav;
    cfg.pini.betac = out_bads.betac;
    cfg.pini.betar = out_bads.betar;
    cfg.pini.theta = out_bads.theta;
    cfg.pini.omega = out_bads.omega;
    cfg.pini.delta = out_bads.delta;
    cfg.pini.sigma = out_bads.sigma;

    % VBMC fitting
    cfg.fitalgo = 'vbmc';
    cfg.nrun    = 1;
    cfg.noprior = 0;

    out_vbmc = fit_modelbound_noisyleaky_comleak(cfg);

    % Save fitting output
    save(fullfile(foldname,filename),'out_bads','out_vbmc','iseq','halfname');

end

end