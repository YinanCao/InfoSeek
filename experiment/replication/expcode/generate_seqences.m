clear; clc; close all;
cd /home/equipe-wyart-2/Documents/Experiment/COLdisc_EEG2025/expcode
restoredefaultpath
addpath ./img
addpath(genpath('./Toolboxes/'))
addpath(genpath('./funcs/'))
sqcdir = '../sqcfiles/';
if ~exist(sqcdir, 'dir')
    mkdir(sqcdir);
end

for subj = 41
sqcFileName = sprintf('../sqcfiles/exp_sqc_eeg_S%02d.mat',subj);
kappa     = 0.5;
twinseq   = 1;
nrep      = 2;
nseqL     = 3;
[sqc, sqc_raw] = COLdisc_expe_fx_gen_expe_sqc(subj, nseqL, twinseq, nrep, kappa);
save(sqcFileName,'sqc')
end




