function run_fit_comleak(subjID,type,dataset)

    subjID = str2double(subjID);
    condlist = [1, 2];
    % load data
    load(['dat_choicestbl_',dataset,'.mat'],'choicestbl');
    choicestbl(choicestbl.excludepart == true,:) = [];
    
    % define list of subjects
    subjlist = unique(choicestbl.subj);
    subjlist = subjlist(subjID);
    
    % define list of fits
    [icond_fit,isubj_fit] = ndgrid(condlist,subjlist);
    isubj_fit = isubj_fit(:);
    icond_fit = icond_fit(:); 
    
    % get number of fits
    nfit = numel(isubj_fit);
    
    % fit models using parallel loop
    for ifit = 1:nfit
        fun_fit_modelbound_noisyleaky(choicestbl,isubj_fit(ifit),icond_fit(ifit),dataset,type);
    end

end

%%
function fun_fit_modelbound_noisyleaky(data,isubj,icond,dataset,type)

if nargin < 3
    error('Missing input arguments!');
end

% set output filename
foldname = ['./fit_',dataset];
filename = sprintf('%s_fit_model_%s_isubj%03d_icond%d.mat', ...
    dataset,type,isubj,icond);
if ~exist(foldname,'dir')
    mkdir(foldname)
end

% add BADS/VBMC toolboxes to path
addpath(genpath(fullfile(fileparts(mfilename('fullpath')),'..','utils','toolbox')))

% get data
iseq    = find(data.subj == isubj & data.condition == icond);
conditn = data.condition(iseq);
targetc = (2*data.targetcolor(iseq)-3).*(conditn ~= 2);
colvals = data.colorseen(iseq);
choices = data.choices(iseq);
nsample = data.nsamples(iseq);

% remove NaN padding from data
nseq = numel(choices);
for iseq = 1:nseq
    colvals{iseq} = colvals{iseq}(:,1:nsample(iseq));
    choices{iseq} = choices{iseq}(1:nsample(iseq));
end

% remove sequences with missing choices
isbad = cellfun(@(x)any(isnan(x)),choices);
targetc(isbad) = [];
colvals(isbad) = [];
choices(isbad) = [];

% create configuration structure
cfg         = [];
cfg.conditn = icond;
cfg.targetc = targetc;
cfg.colvals = colvals;
cfg.choices = choices;

cfg.gamma   = 0.1;

cfg.fitalgo = 'bads';
cfg.noprior = 1;
cfg.npft    = 1000;
cfg.nres    = 100;
cfg.verbose = 2; % fitting display level

switch type
    case 'exact'
    cfg.delta   = 0;
    cfg.sigma   = 0;
    cfg.npft    = 2;
    cfg.nres    = 2;
    case 'comleak'
    cfg.sigma   = 0;
    cfg.npft    = 2;
    cfg.nres    = 2;
    case 'noise'
    cfg.delta   = 0;
    case 'comleaknoise'
    % fit all
    case 'comleakpre'
    cfg.sigma   = 0;
    cfg.npft    = 2;
    cfg.nres    = 2;
    cfg.leakrule = 'pre';
    case 'comleaknoisepre'
    cfg.leakrule = 'pre';
    case 'comleaknoiseNOthres'
    cfg.theta = 0;
    case 'noiseNOthres'
    cfg.delta = 0;
    cfg.theta = 0;
    otherwise
    error('wrong model type!')
end

cfg.nrun = 10; % multiple starting points
out_bads = fit_modelbound_noisyleaky_comleak(cfg);

% set initial values
cfg.pini.betav = out_bads.betav;
cfg.pini.betac = out_bads.betac;
cfg.pini.betar = out_bads.betar;
cfg.pini.theta = out_bads.theta;
cfg.pini.omega = out_bads.omega;
cfg.pini.delta = out_bads.delta;
cfg.pini.sigma = out_bads.sigma;

cfg.fitalgo = 'vbmc';
cfg.nrun    = 1; % single starting point
cfg.noprior = 0;

out_vbmc = fit_modelbound_noisyleaky_comleak(cfg);

% save fitting output to file
save(fullfile(foldname,filename),'out_bads','out_vbmc');

end