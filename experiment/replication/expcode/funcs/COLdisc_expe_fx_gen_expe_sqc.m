function [sqc, sqc_raw] = COLdisc_expe_fx_gen_expe_sqc(subj, nseqL, twinseq, nrep, kappa)
%% making sequences
% (1) define cond, sqc length, counterfactualness, target colors
% (2) get color draws of equalised difficulty for each sequence
% (3) assort seqs for first condition
% (4) mirror them for second condition
% (5) add simulations of the optimal sampling behavior (for scores - fx_get_optsampling)
% (6) divide sequences into blocks and order them within blocks (fx_makeblocks - fx_orderblocks)
fprintf('Creating sequences from >>> fx_gen_expe_sqc\n\n')
tic

if twinseq
    ntwin = 1;
else
    ntwin = nrep;
end
if twinseq && nrep~=2
    error('cannot do twin sequences! check nrep')
end
% - nseq_condition for bandit task, and nseq_condition for guess task;
% - nsamples(8,...,20) x cf(1,2,3) x targetcolors(1,2)
% The basic design is as follows (for each level of sequence length):
% target        - + + - - + - + % [+:orange, -:blue]
% other         - + + - + - + -
% counterfness  1 1 2 2 3 3 3 3
% targetcolor   1 2 1 2 1 2 1 2  % [1:blue, 2:orange] *only meaningful for draw

% there are 2 repeated 'twin' seq for each unique combination of
% {nsamples,cf,targetcolors}

%% defining conditions:
sqc            = struct();
cf_levels      = [1,2,3,3];
targ_levels    = [1,2]; %(1=blue, 2=orange)
seqlen_levels  = linspace(8,20,nseqL); % 8..20
nseq_condition = nseqL * length(cf_levels) * length(targ_levels) * nrep; % L x cf x Targ x rep
%%% bandit/guess sampling condition = 1 or 2
NSEQ           = nseq_condition * 2; % 2 tasks
condition      = [repelem(1,nseq_condition) repelem(2,nseq_condition)];
c = []; % fully balanced design:
for seq_length = seqlen_levels % sequence length
    for cf = cf_levels % counterfactualness
        for targcolor = targ_levels % target color (1=blue, 2=orange)
            for rep = 1:ntwin
                c = [c; seq_length, cf, targcolor];
            end
        end
    end
end
nsamples     = c(:,1)';
counterfness = c(:,2)';
targetcolors = c(:,3)';

probe_target_1st = randi(2,[1,nseq_condition])-1; % 0/1
%%% instuctionside is random
instrside        = randi(2,[1,nseq_condition]);

%%% get a pool of symbol pairs with least amount of repeats, shuffled
symbolpairs = nchoosek(1:8,2); % 28 unique possible symbol pairs
npairs      = size(symbolpairs,1); % get pool to make sure not too many repeats
if nseq_condition <= npairs % if we need fewer pairs, take random pairs, 
    % no need to control > we'll only use to pilot loosely
    pool = symbolpairs(randperm(npairs, nseq_condition),:);
elseif nseq_condition > npairs % if we need more pairs, 
    % try to have least nb of repeats
    padsize = randperm(npairs, mod(nseq_condition,npairs)); 
    % choose unique pairs to add up at the end
    pool = [repmat(symbolpairs, [1, floor(nseq_condition/npairs)]); 
            symbolpairs(padsize,:)]; 
    % pool as many full sets of all pairs + padding
end
pool = pool(randperm(size(pool,1)),:);
% basic unit: nsamples(8,...,20)xcf(1,2,3)xtargetcolors(1,2)
%% get colordraws for the seqs of condition 1: bandit
thetavalues = COLdisc_expe_fx_get_bestthetavalues(nsamples, counterfness, targetcolors, kappa);
%% replicate the sequences for 'twins' if do_twin, except for discRotation
n = length(thetavalues);
for isqc = 1:n
    % randomise symbol sides for each sample, max repeated side = 3
    nrepeated = 3;
    symside = zeros(1, thetavalues(isqc).nsamples); % init as many samples:
    while abs(diff(hist(symside,1:2)))>1 % while not equal number of 1s and 2s
        symside(1:nrepeated) = randi(2,1,nrepeated); %fill the first three
        for i = (nrepeated+1):(thetavalues(isqc).nsamples) % loop on following ones:
            ipos = randi(2,1); % get one random
            if sum(symside((i-nrepeated):(i-1))==ipos)>=nrepeated 
                %if last 3 were already == thisside
                symside(i) = 3-ipos;%take other side
            else; symside(i) = ipos;%else take this side
            end
        end
    end
    thetavalues(isqc).symbolsides = symside;
end
%%
fields = fieldnames(thetavalues); % Get all field names
for i = 1:numel(fields)
    fieldName = fields{i};
    for j = 1:n
         data = thetavalues(j).(fieldName); % Get field data
         if twinseq && nrep==2 % if not doing twins, then just use thetavalues directly
             thetavalues(j + n).(fieldName) = data;
         elseif twinseq && nrep~=2
             error('cannot do twin sequences! check nrep')
         end
    end
end
%% disc shift: evenly spaced, different for all seqs in the task
disc_rot = deg2rad(linspace(0,180,nseq_condition+1));
disc_rot = disc_rot(1:nseq_condition);
disc_rot = disc_rot(randperm(nseq_condition)); % shuffle
for i = 1:nseq_condition
    thetavalues(i).discRotation = disc_rot(i);
end
%% build sequences info in first condition (target):
for isqc = 1:nseq_condition
    
    sqc(isqc).kappa             = thetavalues(isqc).kappa;
    sqc(isqc).genid             = isqc; 
    sqc(isqc).subj              = subj;
    sqc(isqc).condition         = condition(isqc); 
    sqc(isqc).mirroring         = isqc;
    sqc(isqc).seqgenerationidx  = isqc;
    sqc(isqc).twinid            = thetavalues(isqc).twinid;

    sqc(isqc).nsamples          = thetavalues(isqc).nsamples;
    sqc(isqc).counterfness      = thetavalues(isqc).counterfness;
    sqc(isqc).targetcolor       = thetavalues(isqc).targetcolors;
    sqc(isqc).latent            = thetavalues(isqc).latent;
    
    sqc(isqc).symbolpair        = pool(isqc,:);
    sqc(isqc).targetsymbol      = pool(isqc,1);
    sqc(isqc).othersymbol       = pool(isqc,2);
    
    % this is the most important variable:
    % draw equalised-difficulty color values (theta), convert to log-odds
    sqc(isqc).theta.target      = thetavalues(isqc).target';
    sqc(isqc).theta.other       = thetavalues(isqc).other';

    sqc(isqc).discRotation      = thetavalues(isqc).discRotation;

    % convert to log-odds:
    kappa                       = sqc(isqc).kappa;
    sqc(isqc).colorslin.target  = 2*kappa*cos(2*sqc(isqc).theta.target);
    sqc(isqc).colorslin.other   = 2*kappa*cos(2*sqc(isqc).theta.other);

    % % randomise symbol sides for each sample, max repeated side = 3
    % nrepeated = 3;
    % symside = zeros(1, sqc(isqc).nsamples); % init as many samples:
    % while abs(diff(hist(symside,1:2)))>1 % while not equal number of 1s and 2s
    %     symside(1:nrepeated) = randi(2,1,nrepeated); %fill the first three
    %     for i = (nrepeated+1):(sqc(isqc).nsamples) % loop on following ones:
    %         ipos = randi(2,1); % get one random
    %         if sum(symside((i-nrepeated):(i-1))==ipos)>=nrepeated 
    %             %if last 3 were already == thisside
    %             symside(i) = 3-ipos;%take other side
    %         else; symside(i) = ipos;%else take this side
    %         end
    %     end
    % end
    
    sqc(isqc).symbolsides      = thetavalues(isqc).symbolsides;
    sqc(isqc).instrside        = instrside(isqc);
    % % probe question in guess condition:
    sqc(isqc).probe_target_1st = probe_target_1st(isqc);
    
end % end for first half of seq = condition #1

while 1 % balance left/right choices for guess final questions
    probeside_shape1 = randi(2,[1,nseq_condition]);
    probeside_shape2 = randi(2,[1,nseq_condition]);
    optimalFinalChoice = ones(nseq_condition,2);
    for isqc = 1:nseq_condition
        probeside = [probeside_shape1(isqc)
                     probeside_shape2(isqc)];
        switch sqc(isqc).counterfness
            case 1
             target_latent_color = sqc(isqc).targetcolor;
             other_latent_color  = sqc(isqc).targetcolor;
            case 2
             target_latent_color = 3-sqc(isqc).targetcolor;
             other_latent_color  = 3-sqc(isqc).targetcolor;
            case 3
             target_latent_color = sqc(isqc).targetcolor;
             other_latent_color  = 3-sqc(isqc).targetcolor;
        end
        if sqc(isqc).probe_target_1st
            % probesymbol = [targetsymbol,othersymbol];
            probecolor  = [target_latent_color,other_latent_color]; % true answer
        else
            % probesymbol = [othersymbol,targetsymbol];
            probecolor  = [other_latent_color,target_latent_color];
        end
        % looping over 2 shapes probe questions:
        for probe_q = 1:2 % probe both shapes
        
            % order random, pre-determined when generating seq
            % color buttons
            bluebuttonside = probeside(probe_q);% this is the side of the blue bag
            if bluebuttonside==1
                bagcolor = [1,2]; % 1:blue, 2:orange
            elseif bluebuttonside==2
                bagcolor = [2,1];
            end
            optimalFinalChoice(isqc,probe_q) = find(bagcolor==probecolor(probe_q));
        end
    end
    avgL     = mean(optimalFinalChoice(:)==1);
    count_22 = sum(ismember(optimalFinalChoice, [2 2], 'rows'));
    count_11 = sum(ismember(optimalFinalChoice, [1 1], 'rows'));
    count_12 = sum(ismember(optimalFinalChoice, [1 2], 'rows'));
    count_21 = sum(ismember(optimalFinalChoice, [2 1], 'rows'));
    if abs(avgL-0.5)<1e-5 && std([count_22,count_11,count_12,count_21])<1e-5
        break;
    end
end

fprintf('guess final choice: %.3f \n\n', avgL)
for isqc = 1:nseq_condition
    sqc(isqc).probeside_shape1 = probeside_shape1(isqc); 
    sqc(isqc).probeside_shape2 = probeside_shape2(isqc);
end
%% duplicate for 2nd condition (open condition = exact same sequences)
for isqc = nseq_condition+1:NSEQ

    iduplicat                  = isqc - nseq_condition;
    sqc(isqc).genid            = isqc;
    sqc(isqc).subj             = sqc(iduplicat).subj;
    sqc(isqc).condition        = condition(isqc);
    sqc(isqc).mirroring        = iduplicat;
    sqc(isqc).seqgenerationidx = isqc;
    sqc(isqc).twinid           = sqc(iduplicat).twinid;
    sqc(isqc).nsamples         = sqc(iduplicat).nsamples;
    sqc(isqc).counterfness     = sqc(iduplicat).counterfness;
    sqc(isqc).targetcolor      = sqc(iduplicat).targetcolor;
    sqc(isqc).symbolpair       = sqc(iduplicat).symbolpair;
    sqc(isqc).targetsymbol     = sqc(iduplicat).targetsymbol;
    sqc(isqc).othersymbol      = sqc(iduplicat).othersymbol;

    sqc(isqc).theta            = sqc(iduplicat).theta; % theta
    sqc(isqc).colorslin        = sqc(iduplicat).colorslin; % log-odds
    sqc(isqc).discRotation     = sqc(iduplicat).discRotation;

    % side of symbols on screen at each sample
    sqc(isqc).symbolsides      = sqc(iduplicat).symbolsides; 
    % side of symbols on screen at instructions screen
    sqc(isqc).instrside        = sqc(iduplicat).instrside; 
    sqc(isqc).probeside_shape1 = sqc(iduplicat).probeside_shape1;
    sqc(isqc).probeside_shape2 = sqc(iduplicat).probeside_shape2;
    sqc(isqc).probe_target_1st = sqc(iduplicat).probe_target_1st;
    sqc(isqc).kappa            = sqc(iduplicat).kappa;
    sqc(isqc).latent           = sqc(iduplicat).latent;

end %for second half = condition #2

fprintf('Done creating seqs!\n');
%%% adding optimal sampling:
sqc = COLdisc_expe_fx_get_optsampling(sqc);
sqc_raw = sqc;
%%% adding blocks and order in blocks: --also orders the seqs in block, within block
sqc = COLdisc_expe_fx_makeblocks(sqc);
sqc = COLdisc_expe_fx_orderblocks(sqc);

toc

end % function end