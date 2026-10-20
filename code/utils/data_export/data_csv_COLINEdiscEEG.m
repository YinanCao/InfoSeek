clear; clc; close all;

dataset = 'COLdiscEEG';

load(['dat_choicestbl_',dataset,'.mat'],'choicestbl');
choicestbl(choicestbl.excludepart == true,:) = [];
data = choicestbl;
unique_ids = unique(data.subj);
unique_ids = setdiff(unique_ids, 23); % excluded subject
nsubj = numel(unique_ids);

tmp = cell(nsubj,96);

for s = 1:nsubj
    subjid = unique_ids(s);

    for seq = 1:96
        T = data(data.subj==subjid & data.seq==seq,:);

        sampling = [
            T.coloroptions{:}
            T.colorseen{:}
            T.choices{:}
            round(T.choicesrt{:}*1000)
            ]';

        nsmp = T.nsamples;
        sampling = sampling(1:nsmp,:);
        probe_reverse = [1,2];
        if sum(abs(T.symbolpair{:}-T.probesymbol{:}))~=0
            probe_reverse = [2,1];
        end

        guessRESP = [T.finalchoicecorr{:}(probe_reverse), round(T.finalchoicert{:}(probe_reverse)*1000)];

        taskVARS = [T.subj,T.blk,T.seq,T.condition,T.symmetry,...
            T.twinid,T.targetcolor,T.nsamples,T.mirror,T.latent_target,T.latent_other];

        tmp{s,seq} = [repmat([taskVARS,guessRESP],nsmp,1),sampling];
    end
end
tmp = tmp';
allData = vertcat(tmp{:});
% open allData

varNames = {...
    'subj','blk','seq','condition','symmetry','twinid',...
    'targetcolor','nsamples','mirroring','latent1','latent2','finalchoicecorr1','finalchoicecorr2',...
    'finalchoicert1','finalchoicert2','coloroption1','coloroption2','colorseen1','colorseen2','choices','choicesrt'
    };
allTable = array2table(allData,'VariableNames',varNames);

allTable.subj = uint16(allTable.subj);

allTable.blk = uint8(allTable.blk);
allTable.seq = uint8(allTable.seq);
allTable.condition = uint8(allTable.condition);
allTable.symmetry = uint8(allTable.symmetry);
allTable.twinid = uint8(allTable.twinid);
allTable.targetcolor = uint8(allTable.targetcolor);
allTable.nsamples = uint8(allTable.nsamples);
allTable.mirroring = uint8(allTable.mirroring);

% allTable.finalchoicecorr1 = uint8(allTable.finalchoicecorr1);
% allTable.finalchoicecorr2 = uint8(allTable.finalchoicecorr2);
allTable.finalchoicert1 = single(allTable.finalchoicert1);
allTable.finalchoicert2 = single(allTable.finalchoicert2);
 
allTable.coloroption1 = single(allTable.coloroption1);
allTable.colorseen1 = single(allTable.colorseen1);
allTable.coloroption2 = single(allTable.coloroption2);
allTable.colorseen2 = single(allTable.colorseen2);
allTable.choices = uint8(allTable.choices);
allTable.choicesrt = single(allTable.choicesrt);

writetable(allTable,['dat_sampling_',dataset,'.csv']);

disp('all done')