clear; clc; close all;
cd /home/equipe-wyart-2/Documents/Experiment/COLdisc_EEG2025/expcode
addpath ./img
addpath(genpath('./Toolboxes/'))
addpath(genpath('./funcs/'))

debugging  = 0;
frenchmode = 1;
COLdisc_expe_fx_run_tutorial(debugging, frenchmode);

