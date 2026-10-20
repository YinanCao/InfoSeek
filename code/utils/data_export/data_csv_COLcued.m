clear; clc; close all;

dataset = 'COLcued';

load(['dat_choicestbl_',dataset,'.mat'],'choicestbl');
choicestbl(choicestbl.excludepart == true,:) = [];
data = choicestbl;

% Sex/Age: Prolific profile data lost for a few participants -> NaN (not 0)
sexnum = @(x) double(string(x)=="Female") + 0./double(ismember(string(x),["Female","Male"]));
agenum = @(x) str2double(string(x));

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

        tmp{s,seq} = [repmat([taskVARS,guessRESP,sexnum(T.Sex),agenum(T.Age)],nsmp,1),sampling];
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

allTable.subj = castchk(allTable.subj, 'uint16');

allTable.blk = castchk(allTable.blk, 'uint8');
allTable.seq = castchk(allTable.seq, 'uint8');
allTable.condition = castchk(allTable.condition, 'uint8');
allTable.symmetry = castchk(allTable.symmetry, 'uint8');
allTable.targetcolor = castchk(allTable.targetcolor, 'uint8');
allTable.nsamples = castchk(allTable.nsamples, 'uint8');
allTable.latent1 = castchk(allTable.latent1, 'int8');
allTable.latent2 = castchk(allTable.latent2, 'int8');

allTable.finalchoicecorr1 = single(allTable.finalchoicecorr1);
allTable.finalchoicecorr2 = single(allTable.finalchoicecorr2);
allTable.finalchoicert1 = single(allTable.finalchoicert1);
allTable.finalchoicert2 = single(allTable.finalchoicert2);

allTable.coloroption1 = single(allTable.coloroption1);
allTable.coloroption2 = single(allTable.coloroption2);
allTable.colorseen1 = single(allTable.colorseen1);
allTable.colorseen2 = single(allTable.colorseen2);
allTable.choices(allTable.choices==0) = NaN;   % 0 marked a missing response; keep it as NaN
allTable.choices = single(allTable.choices);
allTable.choicesrt = single(allTable.choicesrt);

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
