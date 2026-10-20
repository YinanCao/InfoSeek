clear; clc; close all;

dataset = 'COLcued';

load(['dat_choicestbl_',dataset,'.mat'],'choicestbl');
choicestbl(choicestbl.excludepart == true,:) = [];
data = choicestbl;

unique_ids = unique(data.subj);

lowperf = [18,40,49,52,72,80,91,105,106];
unique_ids = setdiff(unique_ids, lowperf);

nsubj = numel(unique_ids);

tmp = cell(nsubj,80);

for s = 1:nsubj
    subjid = unique_ids(s);

    for seq = 1:80
        T = data(data.subj==subjid & data.seq==seq,:);

        sampling = [
            T.coloroptions{:}
            T.colorseen{:}
            T.choices{:}
            T.choicesrt{:}
            ]';

        nsmp = T.nsamples;
        sampling = sampling(1:nsmp,:);

        guessRESP = [T.finalchoicecorr{:},T.finalchoicert{:}];
        latent = 1 - 2*T.latentBlue{:};

        taskVARS = [T.subj,T.blk,T.seq,T.condition,T.choiceType,T.symmetry,...
            T.targetcolor,T.nsamples,latent];

        tmp{s,seq} = [repmat([taskVARS,guessRESP,T.Sex=='Female',T.Age],nsmp,1),sampling];
    end
end
tmp = tmp';
allData = vertcat(tmp{:});

varNames = {...
    'subj','blk','seq','condition','choicetype','symmetry',...
    'targetcolor','nsamples','latent1','latent2','finalchoicecorr1','finalchoicecorr2',...
    'finalchoicert1','finalchoicert2','female','age','coloroption1','coloroption2',...
    'colorseen1','colorseen2','choices','choicesrt',...
    };

allTable = array2table(allData,'VariableNames',varNames);
% open allTable

allTable.subj = uint16(allTable.subj);

allTable.blk = uint8(allTable.blk);
allTable.seq = uint8(allTable.seq);
allTable.condition = uint8(allTable.condition);
allTable.symmetry = uint8(allTable.symmetry);
allTable.targetcolor = uint8(allTable.targetcolor);
allTable.nsamples = uint8(allTable.nsamples);
allTable.latent1 = int8(allTable.latent1);
allTable.latent2 = int8(allTable.latent2);

allTable.finalchoicecorr1 = single(allTable.finalchoicecorr1);
allTable.finalchoicecorr2 = single(allTable.finalchoicecorr2);
allTable.finalchoicert1 = single(allTable.finalchoicert1);
allTable.finalchoicert2 = single(allTable.finalchoicert2);

allTable.coloroption1 = single(allTable.coloroption1);
allTable.coloroption2 = single(allTable.coloroption2);
allTable.colorseen1 = single(allTable.colorseen1);
allTable.colorseen2 = single(allTable.colorseen2);
allTable.choices = uint8(allTable.choices);
allTable.choicesrt = single(allTable.choicesrt);

allTable.female = uint8(allTable.female);
allTable.age = uint8(allTable.age);

% save(['dat_sampling_',dataset,'.mat'],'allTable','-v7.3');
writetable(allTable,['dat_sampling_',dataset,'.csv']);

disp('all done')
