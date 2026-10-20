clear; clc; close all;
cd /home/equipe-wyart-2/Documents/Experiment/COLdisc_EEG2025/expcode
addpath ./img
addpath(genpath('./Toolboxes/'))
addpath(genpath('./funcs/'))

subj_info;
sqcFile = 'training_sqc.mat';

load(sqcFile,'sqc')
fprintf('kappa = %0.2f \n\n',sqc(1).kappa)

debugging  = 0;
frenchmode = 1;

expout = COLdisc_expe_fx_run_expe(sqc, subj, 1, debugging, 0, 0, 0, 0, 1, frenchmode);