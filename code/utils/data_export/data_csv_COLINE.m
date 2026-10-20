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

allTable.subj = castchk(allTable.subj, 'uint16');

allTable.blk = castchk(allTable.blk, 'uint8');
allTable.seq = castchk(allTable.seq, 'uint8');
allTable.condition = castchk(allTable.condition, 'uint8');
allTable.symmetry = castchk(allTable.symmetry, 'uint8');
allTable.counterfactual = castchk(allTable.counterfactual, 'uint8');
allTable.targetcolor = castchk(allTable.targetcolor, 'uint8');
allTable.nsamples = castchk(allTable.nsamples, 'uint8');
allTable.mirroring = castchk(allTable.mirroring, 'uint8');

allTable.finalchoicecorr = single(allTable.finalchoicecorr);
allTable.finalchoicert = single(allTable.finalchoicert);

allTable.coloroption1 = single(allTable.coloroption1);
allTable.colorseen1 = single(allTable.colorseen1);
allTable.coloroption2 = single(allTable.coloroption2);
allTable.colorseen2 = single(allTable.colorseen2);
allTable.choices(allTable.choices==0) = NaN;   % 0 marked a missing response; keep it as NaN
allTable.choices = single(allTable.choices);
allTable.choicesrt = single(allTable.choicesrt);

allTable.big5_extraversion = single(allTable.big5_extraversion);   % keep NaN for missing values (an integer cast would turn NaN into 0)
allTable.big5_agreeableness = single(allTable.big5_agreeableness);   % keep NaN for missing values (an integer cast would turn NaN into 0)
allTable.big5_conscientiousness = single(allTable.big5_conscientiousness);   % keep NaN for missing values (an integer cast would turn NaN into 0)
allTable.big5_negativeemotionality = single(allTable.big5_negativeemotionality);   % keep NaN for missing values (an integer cast would turn NaN into 0)
allTable.big5_openmindedness = single(allTable.big5_openmindedness);   % keep NaN for missing values (an integer cast would turn NaN into 0)
allTable.icar = single(allTable.icar);   % keep NaN for missing values (an integer cast would turn NaN into 0)
allTable.nfcs = single(allTable.nfcs);   % keep NaN for missing values (an integer cast would turn NaN into 0)

allTable.female = single(allTable.female);   % keep NaN for missing values (an integer cast would turn NaN into 0)
allTable.age = single(allTable.age);   % keep NaN for missing values (an integer cast would turn NaN into 0)

% save(['dat_sampling_',dataset,'.mat'],'allTable','-v7.3');
writetable(allTable,['dat_sampling_',dataset,'.csv']);

disp('all done')

function y = castchk(x, cls)
% Cast to an integer class, but refuse if x contains NaN (MATLAB would silently turn NaN into 0).
assert(~any(isnan(x(:))), 'castchk: NaN found; casting to %s would turn it into 0.', cls);
y = cast(x, cls);
end
