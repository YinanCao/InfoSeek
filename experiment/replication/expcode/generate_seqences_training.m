clear; clc; close all;
restoredefaultpath
addpath(genpath('./Toolboxes/'))
addpath(genpath('./funcs/'))

kappa     = 1.5;
twinseq   = 0;
nrep      = 1;
nseqL     = 3;
[sqc, sqc_raw] = COLdisc_expe_fx_gen_expe_sqc(100, nseqL, twinseq, nrep, kappa);
%%
clc
idx = [];
id = [sqc.nsamples]==14 & [sqc.condition]==1 & [sqc.targetcolor]==1 & [sqc.counterfness]==1; 
id = find(id); idx(1) = id(1);
id = [sqc.nsamples]==14 & [sqc.condition]==1 & [sqc.targetcolor]==2 & [sqc.counterfness]==3; 
id = find(id); idx(2) = id(1);
id = [sqc.nsamples]==14 & [sqc.condition]==2 & [sqc.counterfness]==3; 
id = find(id); idx(3) = id(1);
id = [sqc.nsamples]==14 & [sqc.condition]==2 & [sqc.counterfness]==1; 
id = find(id); idx(4) = id(1);

y = sqc(idx);
sym = {[1,2],[3,4],[5,6],[7,8]};
trlorder = randperm(4);
for i = 1:4
    y(i).symbolpair = sym{i};
    y(i).targetsymbol = sym{i}(1);
    y(i).othersymbol = sym{i}(2);
    y(i).blk = 1;
    y(i).blkseq = trlorder(i);
end
%%
sqc = y;
% save('training_sqc.mat','sqc')


