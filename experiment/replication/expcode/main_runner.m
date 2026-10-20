clear; clc; close all;
cd /home/equipe-wyart-2/Documents/Experiment/COLdisc_EEG2025/expcode
addpath ./img
addpath(genpath('./Toolboxes/'))
addpath(genpath('./funcs/'))

subj_info;
sqcFile = sprintf('../sqcfiles/exp_sqc_eeg_S%02d', subj);

load(sqcFile,'sqc')
fprintf('kappa = %0.2f \n\n',sqc(1).kappa)

debugging  = 0;
eyeON      = 1;
eegON      = 1;
autopilot  = 0;
photodiode = 0;
frenchmode = 1;

nblk = max([sqc.blk]);

for blk = 1:nblk
    fprintf('...Launching experiment now... \n');
    tic
    expout = COLdisc_expe_fx_run_expe(sqc, subj, blk, debugging, eyeON, eegON, photodiode, autopilot, 0, frenchmode);
    toc
end

calculate_score