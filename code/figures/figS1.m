clear; clc; close all;


dataset = 'COLINE';

% Number of model simulations per subject
nModelSim = 10;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Load human data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
load(['dat_choicestbl_',dataset,'.mat'],'choicestbl');
choicestbl(choicestbl.excludepart == true,:) = [];
data = choicestbl;
unique_ids = unique(data.subj);
nsubj = numel(unique_ids);

countmodelfit = load('dat_CountmodelparELBO_COLINE.mat');
thresmodelfit = load('dat_modelparELBO_COLINE.mat');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Analysis settings
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

N = 6;
cfac = 1.4386;
relTrials = -N:-1;
nRelTrials = numel(relTrials);

% Variables:
%   1. target-aligned evidence
%   2. belief-aligned evidence
%   3. belief magnitude
%   4. change rate of belief magnitude
%   5. RT
nVariables = 5;

alignHuman = nan(nsubj,nRelTrials,nVariables,2);
alignCount = nan(nsubj,nRelTrials,nVariables);
alignThres = nan(nsubj,nRelTrials,nVariables);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Loop over subjects
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for s = nsubj:-1:1

    subj_id = unique_ids(s);

    fprintf('Subject %d\n',subj_id)

    % condition-specific data
    for cond = 1:2
        row_idx = find(data.subj == subj_id & data.condition == cond);
    
        conditn = data.condition(row_idx);
        ctfactn = data.symmetry(row_idx);
        targetc_cfg = (2*data.targetcolor(row_idx)-3).*(conditn ~= 2);
        colvals = data.colorseen(row_idx);
        choicesHuman = data.choices(row_idx);
        nsample = data.nsamples(row_idx);
        guesspc = data.finalchoicecorr(row_idx);
        colorop = data.coloroptions(row_idx);
        RT = data.choicesrt(row_idx);
    
        % In the GUESS condition, target direction is undefined
        if cond==2
            targetc_cfg = targetc_cfg*nan;
        end
    
        % Remove NaN padding
        for iseq = 1:numel(choicesHuman)
            colvals{iseq} = colvals{iseq}(:,1:nsample(iseq));
            choicesHuman{iseq} = choicesHuman{iseq}(1:nsample(iseq));
            colorop{iseq} = colorop{iseq}(:,1:nsample(iseq));
            RT{iseq} = RT{iseq}(:,1:nsample(iseq))/1000;
        end
    
        % Remove sequences with missing choices
        isbad = cellfun(@(x)any(isnan(x)),choicesHuman);
    
        conditn(isbad) = [];
        ctfactn(isbad) = [];
        targetc_cfg(isbad) = [];
        colvals(isbad) = [];
        choicesHuman(isbad) = [];
        nsample(isbad) = [];
        guesspc(isbad) = [];
        colorop(isbad) = [];
        RT(isbad) = [];
    
        % Create configuration structure
        cfg = [];
        cfg.conditn = cond;
        cfg.targetc = targetc_cfg;
        cfg.colvals = colvals;
        cfg.colorop = colorop;
        cfg.choices = choicesHuman;
        cfg.same1st = false;
        cfg.shuffle = false;
        cfg.cfac = cfac;
    
        nseq = numel(cfg.choices);
    
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Human trajectories
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        Xhuman = create_switch_table(cfg.choices,cfg.colvals,cfg.colorop,cfg.targetc,RT,cfac,true);
        [alignHuman(s,:,:,cond), n_streak1{s}] = align_first_switch(Xhuman,N);
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Load count-model fit
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    M = countmodelfit.modelfit;
    m = M(M.subj==subj_id & M.("condition(2=guess)")==2, :);
    parsCount = [];
    parsCount.delta = m.deltac; 
    parsCount.sigma = m.sigma;
    parsCount.betav = m.betav;
    parsCount.betac = m.betac; 
    parsCount.betar = m.betar; 
    parsCount.ncrit = m.ncrit;
    parsCount.omega = m.epsilon;

    ncrit(s,1) = parsCount.ncrit;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Load threshold-model fit
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    M = thresmodelfit.modelfit;
    m = M(M.subj==subj_id & M.("condition(1=bandit,2=guess)")==2 ...
        & M.("model(1=exact,2=leak,3=noise,4=leaknoise,5=leaknoiseNOthr)")==4, :);
    parsThres = [];
    parsThres.delta = m.deltac;
    parsThres.sigma = m.sigma;
    parsThres.betav = m.betav;
    parsThres.betac = m.betac;
    parsThres.betar = m.betar;
    parsThres.theta = m.theta;
    parsThres.omega = m.epsilon;
    parsThres.gamma = m.gamma;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Simulation settings
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    cfgSim = cfg;
    % Match each simulated sequence's first choice to the human sequence
    cfgSim.same1st = 1;
    cfgSim.fix1st = false;

    alignedCountSim = nan(nModelSim,nRelTrials,nVariables);
    alignedThresSim = nan(nModelSim,nRelTrials,nVariables);

    RTmodel = cell(nseq,1);

    for iseq = 1:nseq
        RTmodel{iseq} = nan(1,numel(cfg.choices{iseq}));
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Simulate both models
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    for isim = 1:nModelSim

        % Count model
        [mchCount,~,~,~,~,~,~] = sim_modelcountdiscrete_noisyleaky(parsCount.betav,parsCount.betac,parsCount.betar,parsCount.ncrit,...
            parsCount.omega,parsCount.delta,parsCount.delta,parsCount.sigma,cfgSim);

        Xcount = create_switch_table(mchCount,cfg.colvals,cfg.colorop,cfg.targetc,RTmodel,cfac,false);
        alignedCountSim(isim,:,:) = align_first_switch(Xcount,N);

        % Threshold model
        [mchThres,~,~,~,~,~,~] = sim_modelbound_noisyleaky(parsThres.betav,parsThres.betac,parsThres.betar,...
            parsThres.theta,parsThres.omega,parsThres.gamma,parsThres.delta,parsThres.delta,parsThres.sigma,cfgSim);

        Xthres = create_switch_table(mchThres,cfg.colvals,cfg.colorop,cfg.targetc,RTmodel,cfac,false);
        alignedThresSim(isim,:,:) = align_first_switch(Xthres,N);
    end

    % Average simulations within subject
    alignCount(s,:,:) = mean(alignedCountSim,1,'omitnan');
    alignThres(s,:,:) = mean(alignedThresSim,1,'omitnan');
end

disp('done')

size(alignHuman)
size(alignCount)
size(alignThres)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Plot human, count model, and threshold model
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
clc; close all;

configALL
c = lines;

matchColor = c(4,:);
guessColor = c(5,:);

humanColor = c(5,:);
thresColor = c(1,:);
countColor = ones(1,3)*0.60;
gray = ones(1,3)*0.50;
lightGray = ones(1,3)*0.75;

traceColors = [matchColor; guessColor];

relTrials = -N:-1;

cfgPlot = [];
cfgPlot.plotline = 1;
cfgPlot.linewidth = 2;
cfgPlot.plotdots = 0;
cfgPlot.alpha = 0.2;

% Condition indices
MATCH = 1;
GUESS = 2;

% Variable indices
TARGET_ALIGNED = 1;
BELIEF_ALIGNED = 2;
BELIEF_MAG = 3;
LEARNING_PROGRESS = 4;
RT = 5;

figure('Position',[420 274 900 600]);
tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

% ------------------------------------------------------------------------
% Panels 1–2: Human evidence trajectories
% -------------------------------------------------------------------------

measureIdx = [TARGET_ALIGNED BELIEF_ALIGNED];
measureNames = {'target-aligned evidence','belief-aligned evidence'};

for iPanel = 1:2

    nexttile;
    hold on;

    measure = measureIdx(iPanel);
    thisData = squeeze(alignHuman(:,:,measure,:));

    h = plotpatch(thisData,relTrials,traceColors,cfgPlot);

    plot(relTrials,zeros(size(relTrials)),'--','Color',gray);

    format_switch_axis(relTrials,[-0.5 0.5],fs);
    add_switch_marker(lightGray,gray,fs);

    ylabel(measureNames{iPanel});

    if iPanel == 1
        hx = xlabel('outcome index relative to first switch');
        hx.Units = 'normalized';
        hx.Position(1) = hx.Position(1) + 0.7;

        legend(h,'match','Location','northwest','Box','off','AutoUpdate','off');
    else
        legend(h,{'match','guess'},'Location','northwest','Box','off','AutoUpdate','off');
    end

    title('Human','FontWeight','normal','FontName','Arial');
end

% ------------------------------------------------------------------------
% Panel 3: Belief-aligned evidence immediately before first switch
% -------------------------------------------------------------------------

nexttile;
hold on;

d = [alignHuman(:,end,BELIEF_ALIGNED,GUESS), ...
     alignThres(:,end,BELIEF_ALIGNED), ...
     alignCount(:,end,BELIEF_ALIGNED)];

countM_valid = ~isnan(d(:,3));
d = d(countM_valid, :);

m = mean(d,1,'omitnan');
se = std(d,0,1,'omitnan') ./ sqrt(sum(~isnan(d),1)) * 1.96;

barFaceColors = [humanColor; thresColor; 1 1 1];
barEdgeColors = [humanColor; thresColor; countColor];

for i = 1:3

    b = bar(i,m(i),'FaceColor',barFaceColors(i,:),'EdgeColor',barEdgeColors(i,:),'LineWidth',1.5);

    b.FaceAlpha = alpha;
    b.EdgeAlpha = min(alpha*2,1);

    errorbar(i,m(i),se(i),'Color',barEdgeColors(i,:),'LineWidth',1.5,'CapSize',0);
end

set(gca,'Box','off','FontSize',fs,'FontName','Arial','TickDir','out','Color','none','LineWidth',1);

xlim([0.05 3.95]);

for i = 1:3
    color = barEdgeColors(i,:);
    jitter_scatter(d(:,i), i, color, 0, 5, 0.06, 30)
end
ylim([-1, 1])
yticks(-1:0.5:+1)

text(1,0.35,'*','HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontSize',fs,'FontName','Arial','Color',darkred);
text(2,0.12,'*','HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontSize',fs,'FontName','Arial','Color',darkred);
text(3,0.02,'n.s.','HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontSize',fs-2,'FontName','Arial');

xticks(1:3);
xticklabels({'Human','Threshold model','Count model'});
ylabel('belief-aligned evidence in GUESS');


[~,p,~,stats] = ttest(d);
[p_corr] = Bonf_Holm_yc(p, 0.05);       % Holm only across the 4 lengths
dz = mean(d,'omitnan') ./ std(d,'omitnan'); % Cohen's d_z for paired data
lab = {'Human','Thres','Count'};
fprintf('\nTwo-sided paired t-tests (cond 2 vs 3)\n');
fprintf('Type\tt\tdf\td_z\tp\n');
for i = 1:numel(lab)
    fprintf('%s\t%.2f\t%d\t%.2f\t%.4f\n', lab{i}, stats.tstat(i), stats.df(i), dz(i), p_corr(i));
end





% ------------------------------------------------------------------------
% Panels 4–5: Belief magnitude in GUESS
% -------------------------------------------------------------------------

beliefMagnitudeData = cat(3, ...
    alignHuman(:,:,BELIEF_MAG,GUESS), ...
    alignThres(:,:,BELIEF_MAG));

modelNames = {'Human','Threshold model'};
modelColors = [humanColor; thresColor];

for iPanel = 1:2

    nexttile;
    hold on;

    plotpatch(beliefMagnitudeData(:,:,iPanel),relTrials,modelColors(iPanel,:),cfgPlot);

    format_switch_axis(relTrials,[0.9 2],fs);
    add_switch_marker(lightGray,gray,fs);

    if iPanel == 1
        hx = xlabel('outcome index relative to first switch');
        hx.Units = 'normalized';
        hx.Position(1) = hx.Position(1) + 0.7;

        ylabel('belief magnitude in GUESS');
    else
        set(gca,'YColor','none');
    end

    title(modelNames{iPanel},'FontWeight','normal','FontName','Arial');
end

% ------------------------------------------------------------------------
% Panel 6: Human reaction time
% -------------------------------------------------------------------------

nexttile;
hold on;

thisData = squeeze(alignHuman(:,:,RT,:));

h = plotpatch(thisData,relTrials,traceColors,cfgPlot);

legend(h,{'match','guess'},'Location','northwest','Box','off','AutoUpdate','off');

format_switch_axis(relTrials,[0.45 0.70],fs);
add_switch_marker(lightGray,gray,fs);

yticks([0.45 0.70]);

ylabel('reaction time (s)');
xlabel('outcome index relative to first switch');

title('Human','FontWeight','normal','FontName','Arial');

% ------------------------------------------------------------------------
% Local functions
% -------------------------------------------------------------------------

function format_switch_axis(relTrials,yLim,fs)

    set(gca,'Box','off','FontSize',fs,'FontName','Arial','TickDir','out','Color','none','LineWidth',1,'XTick',relTrials);

    xlim([min(relTrials)-0.1 0]);
    ylim(yLim);

end

function add_switch_marker(lineColor,textColor,fs)

    yl = ylim;
    textY = yl(2)-0.10*diff(yl);
    yl(2) = textY;

    plot([-0.5 -0.5],yl,'--','LineWidth',2,'Color',lineColor);

    text(-0.5,textY,'Switch','HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontSize',fs-1,'FontName','Arial','Color',textColor);

end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Local function: construct trial-level switch table
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function X = create_switch_table(choices,colvals,colorop,targetc,RT,cfac,includeRT)

    X = [];
    nseq = numel(choices);

    for iseq = 1:nseq

        ch = choices{iseq};
        c = colvals{iseq}'*cfac;

        true_c = colorop{iseq}'*cfac;
        latent = sum(true_c);

        % Belief before observing the outcome on the current trial
        xc = zeros(size(c,1),2);
        xc(2:end,:) = cumsum(c(1:end-1,:),1,'omitnan');

        chosen_prior = nan(size(ch,2),1);
        chosen_latent = nan(size(ch,2),1);

        for trl = 1:size(xc,1)
            chosen_prior(trl) = xc(trl,ch(trl));
            chosen_latent(trl) = latent(ch(trl));
        end

        chosen_evi = sum(c,2,'omitnan');
        belief_aligned_evi = chosen_evi.*sign(chosen_prior);
        target_aligned_evi = targetc(iseq)*chosen_evi;
        % p_repeat_next = [ch(2:end) == ch(1:end-1),nan]';

        ntrl = length(ch);
        trlid = (1:ntrl)';
        seqid = iseq*ones(ntrl,1);

        belief_aligned_evi(trlid == 1) = nan;
        % target_aligned_evi(trlid == 1) = nan;

        belief_magnitude = abs(cumsum(chosen_evi));
        learning_progress = [NaN; diff(belief_magnitude)];

        if includeRT
            rt_seq = RT{iseq}';
            rt_seq(rt_seq > 5 | rt_seq < 0.1) = nan;
        else
            rt_seq = nan(ntrl,1);
        end

        X = [X;seqid,trlid,ch',target_aligned_evi,belief_aligned_evi,belief_magnitude,learning_progress,rt_seq];
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Local function: align variables around first switch
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [aligned,n_streak1] = align_first_switch(X,N)

    nVariables = size(X,2)-3;
    relTrials = -N:-1;
    aligned = nan(numel(relTrials),nVariables);

    X_out = [X,nan(size(X,1),1)];
    seq_ids = unique(X(:,1));
    n_streak1 = nan(length(seq_ids),1);

    for i = 1:length(seq_ids)

        seq = seq_ids(i);
        idx = find(X(:,1) == seq);
        D = X(idx,:);
        D = sortrows(D,2);

        trial_indices = idx;
        choices = D(:,3);

        switch_pos = find(choices(2:end) ~= choices(1:end-1),1,'first')+1;
        
        if ~isempty(switch_pos)
            n_streak1(i) = switch_pos-1;
            n_back = min(N,switch_pos-1);
            % n_forward = min(1,length(choices)-switch_pos);
            n_forward = -1;
            sel = (switch_pos-n_back):(switch_pos+n_forward);
            rel_range = (-n_back:n_forward)';

            X_out(trial_indices(sel),end) = rel_range;
        end
    end

    for irel = 1:numel(relTrials)
        n = relTrials(irel);
        aligned(irel,:) = mean(X_out(X_out(:,end) == n,4:end-1),1,'omitmissing');
    end

end