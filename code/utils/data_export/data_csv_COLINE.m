clear; clc; close all;

dataset = 'COLINE';

load(['dat_choicestbl_',dataset,'.mat'],'choicestbl');
choicestbl(choicestbl.excludepart == true,:) = [];
data = choicestbl;

unique_ids = unique(data.subj);
nsubj = numel(unique_ids);

tmp = cell(nsubj,64);

for s = 1:nsubj
    subjid = unique_ids(s);

    for seq = 1:64
        T = data(data.subj==subjid & data.seq==seq,:);

        sampling = [
            T.coloroptions{:}
            T.colorseen{:}
            T.choices{:}
            T.choicesrt{:}
            ]';

        nsmp = T.nsamples;
        sampling = sampling(1:nsmp,:);

        guessRESP = [T.finalchoicecorr,T.finalchoicert];

        taskVARS = [T.subj,T.blk,T.seq,T.condition,T.symmetry,...
            T.counterfactual,T.targetcolor,T.nsamples,T.mirroring];

        tmp{s,seq} = [repmat([taskVARS,guessRESP],nsmp,1),sampling];
    end
end
tmp = tmp';
allData = vertcat(tmp{:});

load(['dat_bigtbl_',dataset,'.mat'],'bigtbl');

score = nan(nsubj,7);
sex = nan(nsubj,1);
age = nan(nsubj,1);

for s = 1:nsubj
    idx = find(bigtbl.subj==unique_ids(s),1);

    score(s,:) = [bigtbl.big5_domains(idx,:),...
        bigtbl.icar_total(idx),...
        bigtbl.nfcs_total(idx)];

    sex(s) = bigtbl.female(idx);
    age(s) = bigtbl.age(idx);
end

[~,subjIdx] = ismember(allData(:,1),unique_ids);

allData = [allData,...
    score(subjIdx,:),...
    sex(subjIdx),...
    age(subjIdx)];

varNames = {...
    'subj','blk','seq','condition','symmetry','counterfactual',...
    'targetcolor','nsamples','mirroring','finalchoicecorr',...
    'finalchoicert','coloroption1','coloroption2','colorseen1','colorseen2','choices','choicesrt',...
    'big5_extraversion','big5_agreeableness','big5_conscientiousness',...
    'big5_negativeemotionality','big5_openmindedness',...
    'icar','nfcs','female','age'};

allTable = array2table(allData,'VariableNames',varNames);

allTable.subj = uint16(allTable.subj);

allTable.blk = uint8(allTable.blk);
allTable.seq = uint8(allTable.seq);
allTable.condition = uint8(allTable.condition);
allTable.symmetry = uint8(allTable.symmetry);
allTable.counterfactual = uint8(allTable.counterfactual);
allTable.targetcolor = uint8(allTable.targetcolor);
allTable.nsamples = uint8(allTable.nsamples);
allTable.mirroring = uint8(allTable.mirroring);

allTable.finalchoicecorr = single(allTable.finalchoicecorr);
allTable.finalchoicert = single(allTable.finalchoicert);

allTable.coloroption1 = single(allTable.coloroption1);
allTable.colorseen1 = single(allTable.colorseen1);
allTable.coloroption2 = single(allTable.coloroption2);
allTable.colorseen2 = single(allTable.colorseen2);
allTable.choices = uint8(allTable.choices);
allTable.choicesrt = single(allTable.choicesrt);

allTable.big5_extraversion = uint8(allTable.big5_extraversion);
allTable.big5_agreeableness = uint8(allTable.big5_agreeableness);
allTable.big5_conscientiousness = uint8(allTable.big5_conscientiousness);
allTable.big5_negativeemotionality = uint8(allTable.big5_negativeemotionality);
allTable.big5_openmindedness = uint8(allTable.big5_openmindedness);
allTable.icar = uint8(allTable.icar);
allTable.nfcs = uint16(allTable.nfcs);

allTable.female = uint8(allTable.female);
allTable.age = uint8(allTable.age);

% save(['dat_sampling_',dataset,'.mat'],'allTable','-v7.3');
writetable(allTable,['dat_sampling_',dataset,'.csv']);

disp('all done')