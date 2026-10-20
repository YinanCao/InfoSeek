clear; clc; close all;

% indicate subject ID and model type
subjID = '1'; % must be a string (useful for slurm...)
type = 'comleaknoise'; % e.g., full model (leaky and noisy)
%%
% to fit main binary-choice dataset (N = 420)
dataset = 'COLINE';
run_fit_comleak(subjID,type,dataset)
%%
% to fit replication dataset (N = 39)
dataset = 'COLdiscEEG';
INFresp = '1'; % use final questions to constrain particle trajectories
condition = '2'; % GUESS condition
run_fit_comleak_INFresp(subjID,type,dataset,INFresp,condition)
%%
% to fit ternary-choice generalization dataset (N = 243)
dataset = 'COLINEternary';
run_fit_comleak_3bags(subjID,type,dataset)
%%


