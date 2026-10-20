clear; clc; close all;

dataset = 'COLINEternary';

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
        latent = 1 - 2*T.latentBlue{:};

        taskVARS = [T.subj,T.blk,T.seq,T.condition,T.symmetry,...
            T.counterfactual,T.targetcolor,T.nsamples,latent];

        tmp{s,seq} = [repmat([taskVARS,guessRESP,T.Sex=='Female',T.Age],nsmp,1),sampling];
    end
end
tmp = tmp';
allData = vertcat(tmp{:});

varNames = {...
    'subj','blk','seq','condition','symmetry','counterfactual',...
    'targetcolor','nsamples','latent1','latent2','latent3','finalchoicecorr',...
    'finalchoicert','female','age','coloroption1','coloroption2','coloroption3',...
    'colorseen1','colorseen2','colorseen3','choices','choicesrt',...
    };

allTable = array2table(allData,'VariableNames',varNames);

allTable.subj = uint16(allTable.subj);

allTable.blk = uint8(allTable.blk);
allTable.seq = uint8(allTable.seq);
allTable.condition = uint8(allTable.condition);
allTable.symmetry = uint8(allTable.symmetry);
allTable.counterfactual = uint8(allTable.counterfactual);
allTable.targetcolor = uint8(allTable.targetcolor);
allTable.nsamples = uint8(allTable.nsamples);
allTable.latent1 = int8(allTable.latent1);
allTable.latent2 = int8(allTable.latent2);
allTable.latent3 = int8(allTable.latent3);

allTable.finalchoicecorr = single(allTable.finalchoicecorr);
allTable.finalchoicert = single(allTable.finalchoicert);

allTable.coloroption1 = single(allTable.coloroption1);
allTable.coloroption2 = single(allTable.coloroption2);
allTable.coloroption3 = single(allTable.coloroption3);
allTable.colorseen1 = single(allTable.colorseen1);
allTable.colorseen2 = single(allTable.colorseen2);
allTable.colorseen3 = single(allTable.colorseen3);
allTable.choices = uint8(allTable.choices);
allTable.choicesrt = single(allTable.choicesrt);

allTable.female = uint8(allTable.female);
allTable.age = uint8(allTable.age);

% save(['dat_sampling_',dataset,'.mat'],'allTable','-v7.3');
writetable(allTable,['dat_sampling_',dataset,'.csv']);

disp('all done')
