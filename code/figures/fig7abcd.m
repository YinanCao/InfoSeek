clear;clc;close all;
rng(1234);
dataset = 'COLINE';
% load human data;
load(['dat_choicestbl_',dataset,'.mat'],'choicestbl');
choicestbl(choicestbl.excludepart == true,:) = [];
data = choicestbl;
unique_ids = unique(data.subj);
nsubj = numel(unique_ids);

load dat_modelparELBO_COLINE.mat
M = table2array(modelfit);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Loop over each unique subject ID
type_name = {'comleaknoise','comleaknoiseNOthres'};
nsmpMax   = 20;
seqLength = [8,12,16,20];
nModel    = length(type_name);
elbo      = nan(nsubj,2,nModel);
prepeat   = nan(nsubj,nsmpMax,2,1);
cfac      = 1.4386;

for s = nsubj:-1:1
    subj_id = unique_ids(s);
    
    % Find files for this subject for each condition and model
    for cond = 1:2
        
        % get raw data
        iseq = find(data.subj == subj_id & data.condition == cond);
        conditn = data.condition(iseq);
        ctfactn = data.symmetry(iseq);
        targetc = (2*data.targetcolor(iseq)-3); % -1:blue,+1:orange
        targetc_cfg = (2*data.targetcolor(iseq)-3).*(conditn ~= 2);
        colvals = data.colorseen(iseq);
        choices = data.choices(iseq);
        nsample = data.nsamples(iseq);
        guesspc = data.finalchoicecorr(iseq);
        colorop = data.coloroptions(iseq);
        % remove NaN padding from data
        for iseq = 1:numel(choices)
            colvals{iseq} = colvals{iseq}(:,1:nsample(iseq));
            choices{iseq} = choices{iseq}(1:nsample(iseq));
            colorop{iseq} = colorop{iseq}(:,1:nsample(iseq));
        end
        % remove sequences with missing choices
        isbad = cellfun(@(x)any(isnan(x)),choices);
        conditn(isbad) = [];
        ctfactn(isbad) = [];
        targetc(isbad) = [];
        targetc_cfg(isbad) = [];
        colvals(isbad) = []; % chosen
        choices(isbad) = [];
        nsample(isbad) = [];
        guesspc(isbad) = [];
        colorop(isbad) = [];

        % create configuration structure
        cfg         = [];
        cfg.conditn = cond;
        cfg.targetc = targetc_cfg; % for simulation!
        cfg.colvals = colvals;
        cfg.colorop = colorop; % for simulation!
        cfg.choices = choices;

        seql = cellfun(@(x)size(x,2),cfg.choices);
        nseq = length(cfg.choices);
        
        for type = 1:2
        model_index = [4,5];
        % get raw data
        irow = modelfit.subj==subj_id &...
        modelfit.("model(1=exact,2=leak,3=noise,4=leaknoise,5=leaknoiseNOthr)")==model_index(type) &...
        modelfit.("condition(1=bandit,2=guess)")==cond;
        out = modelfit(irow,:);

        betav   = out.betav;   % 0 for guess task
        betac   = out.betac;
        betar   = out.betar;
        theta   = out.theta;
        epsilon = out.epsilon;
        gamma   = out.gamma;   % fixed: 0.1
        delta_c = out.deltac;   % leak chosen
        delta_u = out.deltau;   % leak unchosen
        sigma = out.sigma;   % inference noise
        parameter(s,:,type,cond) = [delta_c,sigma,betav,betac,betar,theta,epsilon];
        elbo(s,cond,type,:) = out.elbo;
        end
       
        %%%%%%%%%%%%%%%%%%%%%%%%
        % policy-guided choice:
        %%%%%%%%%%%%%%%%%%%%%%%%
        mvopt = cell(0); 
        mcopt = cell(0);
        for iseq = 1:nseq
            c  = cfg.colvals{iseq}';
            c  = c*cfac;
            xc = zeros(size(c,1),2);
            xc(2:end,:) = cumsum(c(1:end-1,:),1,'omitnan');
            
            [~, tempopt] = max(xc*cfg.targetc(iseq),[],2); % target-guided
            mvopt{iseq,1} = [cfg.choices{iseq}==tempopt' nan(1,20-size(cfg.choices{iseq},2))];
            mvopt{iseq,1}(xc(:,1)==xc(:,2)) = nan; % if options are equal, nan

            [~, tempopt] = min(abs(xc),[],2); % uncertainty-guided
            mcopt{iseq,1} = [cfg.choices{iseq}==tempopt' nan(1,20-size(cfg.choices{iseq},2))];
            mcopt{iseq,1}(abs(xc(:,1))==abs(xc(:,2))) = nan; % if options are equal, nan
        end
        dir_c(s,:,cond,1) = mean(cell2mat(mcopt),1,'omitnan');
        dir_v(s,:,cond,1) = mean(cell2mat(mvopt),1,'omitnan');

        %%%%%%%%%%%%%%%%%%%%%%%%
        % fraction repeat:
        %%%%%%%%%%%%%%%%%%%%%%%%
        sprevch  = nan(nseq,nsmpMax);
        srepeat  = nan(nseq,nsmpMax);
        for iseq = 1:nseq
            ch = cfg.choices{iseq};
            nsmp = numel(ch);
            for ismp = 1:nsmp-1
                sprevch(iseq,ismp) = sum(ch(1:ismp)==ch(ismp));
                srepeat(iseq,ismp) = ch(ismp)==ch(ismp+1);
            end
        end
        for idx = 1:max(max(sprevch))
            ich = find(sprevch==idx);
            prepeat(s,idx,cond,1) = mean(srepeat(ich),'omitnan');
        end

        if cond == 1 % match
            for k = 1:length(seqLength)
                ch_cf = cfg.choices(ctfactn==3 & nsample==seqLength(k));
                matrix_ch_cf = cell2mat(ch_cf);
                acc = double(matrix_ch_cf==1);
                acc(isnan(matrix_ch_cf)) = nan;
                pc_match{k}(s,:) = mean(acc,1,'omitnan');
            end
        end

        if cond == 2 % guess task
            pc_guess(s,:) = arrayfun(@(l)mean(guesspc(seql==l)),seqLength);
        end

    end % condition (match/guess)

end % subj

% tendency of streaking
ToC = double((elbo(:,[2,2],1) - elbo(:,[2,2],2))>0); % free vs. fixed theta, guess
size(ToC);
% ToC = double((elbo(:,[1,1],1) - elbo(:,[1,1],2))>0);

%%
clc; close all;
configALL

[ns,ncond,nmodel] = size(elbo);
% run Bayesian model selection in each condition
pavg_mod = nan(ncond, nmodel);  % prevalence
pstd_mod = nan(ncond, nmodel);  % prevalence s.d.
pexc_mod = nan(ncond, nmodel);  % exceedance probabilities
alphas   = nan(ncond, nmodel);  % alphas of the Drch distributions
credint_lower = nan(ncond, nmodel);
credint_upper = nan(ncond, nmodel);
for icond = 1:ncond
    lme = squeeze(elbo(:,icond,:));
    % run BMS
    [alpha,~,~,xpexc]    = spm_BMS(lme);
    [pavg,pvar]       = drchstat(alpha);
    pavg_mod(icond,:) = pavg;
    pstd_mod(icond,:) = sqrt(diag(pvar));
    pexc_mod(icond,:) = xpexc;
    alphas(icond,:)   = alpha;

    nsamples = 10000; % Dirichlet draws for 95% credible intervals
    samples = drchrnd(alpha, nsamples);  % each row is a sample of probabilities
    % then for each model:
    q025 = quantile(samples, 0.025, 1);
    q975 = quantile(samples, 0.975, 1);
    % store them
    credint_lower(icond,:) = q025;
    credint_upper(icond,:) = q975;

    seed = 45;
    rng(seed);
    B = 10000;
    n = size(lme,1);
    d        = lme(:,1) - lme(:,2);         % per-subject log-BF
    log10BF  = sum(d) / log(10);            % point estimate
    log10BF_boot = zeros(B,1);
    for b = 1:B
        idx = randsample(n, n, true);
        log10BF_boot(b) = sum(lme(idx,1) - lme(idx,2)) / log(10);
    end
    ci = quantile(log10BF_boot, [0.025 0.975]);
    out.log10BF = log10BF;
    out.ci      = ci;
    out.B       = B;
    out.seed    = seed;
    fprintf('log10BF = %.3f, 95%% CI [%.3f, %.3f], B = %d, seed = %d\n', ...
            log10BF, ci(1), ci(2), B, seed);

end

configALL;
col = [];
col(1,:) = match;
col(2,:) = guess;

figure('position',[420   274   958   464])

for icond = 1:2
    ax = subplot(2,4,(3-icond-1)*4+1);
    for k = 1:nmodel
        c = condcolor{icond};
        b = bar(k,pavg_mod(icond,k),'FaceColor',c,'EdgeColor',c,'linewidth',barlw);
        b.FaceAlpha = alpha;
        b.EdgeAlpha = alpha*2;
        hold on
        errorbar(k, pavg_mod(icond,k), ...
             pavg_mod(icond,k) - credint_lower(icond,k), ...
             credint_upper(icond,k) - pavg_mod(icond,k), ...
             'color', c, 'linewidth', barlw, 'CapSize', 0);
        set(ax, 'box', 'off', ...
            'color', 'none', ...
            'tickdir', 'out', ...
            'fontsize', fs, ...
            'XTick', [],'linewidth',1,'ytick',[0,0.5,1]);
        ylim(ax, [0, 1]);
        ylabel(ax, 'model prevalence');
        xlabel(ax, 'model')
    end
    chance = 1/nmodel;
    bw = b.BarWidth;
    first_left = 1 - bw/2;
    plot([-10, first_left], [chance chance],'--','color', chancecolor, 'linewidth', 1);
    % draw between bars
    for k = 1:(nmodel-1)
        right_edge = k + bw/2;
        next_left = (k+1) - bw/2;
        plot([right_edge next_left], [chance chance], 'color', chancecolor, 'linewidth', 1);
    end
    % draw after last bar
    last_right = nmodel + bw/2;
    plot([last_right 10], [chance chance], 'color', chancecolor, 'linewidth', 1);

    xt = 1:nmodel;
    name = {'free \theta','fixed \theta = 0'};
    ypos = [0.3, 0.25];
    for i = 1:length(xt)
        text(xt(i), ypos(i), name{i}, ...
         'HorizontalAlignment', 'left', 'Rotation', 90, ...
         'VerticalAlignment', 'middle',...
         'Color',c, 'FontSize', fs);
    end

    title_name = {'match','guess'};
    tt = title(ax, title_name{icond}); 
    tt.FontWeight = 'normal'; 
    tt.Color = condcolor{icond};
    of = 1;
    xlim([1-of,nmodel+of])

    pexc = pexc_mod(icond,:);
    [~,k] = max(pexc);
    yp = credint_upper(icond,k)+0.03;
    plot(1:nmodel,ones(1,nmodel)*yp,'color','k')
    plot([k,k],[yp,yp-0.02],'color','k')
    % Pexc label from the computed protected exceedance probability
    pmax = max(pexc);
    if pmax > 0.99
        ptxt = '\itP\rmexc > .99';
    else
        ptxt = sprintf('\\itP\\rmexc = %.2f', pmax);
    end
    fprintf('Protected exceedance probability of the winning model (cond %d): %.4f\n', icond, pmax);
    % text(1, yp+0.05, '\itP\rmexc > .99');  (original)
    text(1, yp+0.05, ptxt);
end

ax = subplot(2,4,6);
ylimrange = [0.5,1];
sd = 1.96;
liim = 10;
icond = 1;
lw = [0.5, 1.5];
store_d = cell(0);
for whichgroup = [0, 1]
    idx = ToC(:,icond)==whichgroup;
    data = prepeat(idx,:,:);
    store_d{whichgroup+1} = data;
    nsubj = size(data,1);
    hold on
    x_ax     = 1:liim;
    % sphat    = bsxfun(@minus,data,mean(data(:,x_ax,:),2,'omitnan')); % within-participant version (replaced)
    X_patch  = [x_ax, fliplr(x_ax)];
    % yup      = mean(data(:,x_ax,icond),'omitnan') + ( std( sphat(:,x_ax,icond),'omitnan') / sqrt(nsubj)*sd ) ;
    % ylo      = mean(data(:,x_ax,icond),'omitnan') - ( std( sphat(:,x_ax,icond),'omitnan') / sqrt(nsubj)*sd ) ;
    % 95% CI across participants within the subgroup, at each point
    D        = data(:,x_ax,icond);
    nD       = sum(~isnan(D),1);   % participants with data at each point
    yup      = mean(D,'omitnan') + std(D,'omitnan')./sqrt(nD)*sd;
    ylo      = mean(D,'omitnan') - std(D,'omitnan')./sqrt(nD)*sd;
    Y_patch  = [yup, flip(ylo)];
    fill(X_patch, Y_patch , 1, 'facecolor', 0.5*(col(icond,:)+1), 'edgecolor','none', 'facealpha', alpha*(whichgroup+1));
    plot(x_ax, mean(data(:,x_ax,icond),'omitnan'), lstyle{whichgroup+1}, 'Color', col(icond,:), 'LineWidth', lw(whichgroup+1));
end
xlabel('times seen before')
ylabel(sprintf('p(repeat next)'));
set(gca,'xtick',[1,4,7,10],'ytick',0.5:0.25:1)
set(gca,'color','none','linewidth',1,'tickdir','out','fontsize',fs)
ylim(ylimrange)
xlim([0.5,liim])
text(1,0.77,'streaking','color',col(1,:),'FontSize',fs/1.2)
col_faded = (1 - 0.5) * [1 1 1] + 0.5 * col(1,:);
text(1,0.6,'non-streaking','color',col_faded,'FontSize',fs/1.2)
title_name = {'match','guess'};
tt = title(ax, title_name{icond}); 
tt.FontWeight = 'normal'; 
tt.Color = condcolor{icond};
[~,p] = ttest2(store_d{1}, store_d{2}, 'Vartype', 'unequal');
p = squeeze(p);

pthres = 0.005;
qvals = find(mafdr(p(:,icond), 'BHFDR', true)<pthres);
draw_sig(qvals, 0.95, siglw, chancecolor)
% plot(qvals,qvals*0+0.95+(icond-1)*0.035,'-','linewidth',5,'color',condcolor{1})

ax = subplot(2,4,2);
ylimrange = [0.5,1];
sd = 1.96;
liim = 10;
icond = 2;
lw = [0.5, 1.5];
store_d = cell(0);
for whichgroup = [0, 1]
    idx = ToC(:,icond)==whichgroup;
    data = prepeat(idx,:,:);
    store_d{whichgroup+1} = data;
    nsubj = size(data,1);
    hold on
    x_ax     = 1:liim;
    % sphat    = bsxfun(@minus,data,mean(data(:,x_ax,:),2,'omitnan')); % within-participant version (replaced)
    X_patch  = [x_ax, fliplr(x_ax)];
    % yup      = mean(data(:,x_ax,icond),'omitnan') + ( std( sphat(:,x_ax,icond),'omitnan') / sqrt(nsubj)*sd ) ;
    % ylo      = mean(data(:,x_ax,icond),'omitnan') - ( std( sphat(:,x_ax,icond),'omitnan') / sqrt(nsubj)*sd ) ;
    % 95% CI across participants within the subgroup, at each point
    D        = data(:,x_ax,icond);
    nD       = sum(~isnan(D),1);   % participants with data at each point
    yup      = mean(D,'omitnan') + std(D,'omitnan')./sqrt(nD)*sd;
    ylo      = mean(D,'omitnan') - std(D,'omitnan')./sqrt(nD)*sd;
    Y_patch  = [yup,flip(ylo)];
    fill(X_patch, Y_patch , 1, 'facecolor', 0.5*(col(icond,:)+1), 'edgecolor','none', 'facealpha', alpha*(whichgroup+1));
    plot(x_ax, mean(data(:,x_ax,icond),'omitnan'), lstyle{whichgroup+1}, 'Color', col(icond,:), 'LineWidth', lw(whichgroup+1));
end
xlabel('times seen before')
ylabel(sprintf('p(repeat next)'));
set(gca,'xtick',[1,4,7,10],'ytick',0.5:0.25:1)
set(gca,'color','none','linewidth',1,'tickdir','out','fontsize',fs)
ylim(ylimrange)
xlim([0.5,liim])
text(1,0.91,'streaking','color',col(2,:),'FontSize',fs/1.2)
col_faded = (1 - 0.5) * [1 1 1] + 0.5 * col(2,:);
text(1,0.63,'non-streaking','color',col_faded,'FontSize',fs/1.2)
title_name = {'match','guess'};
tt = title(ax, title_name{icond}); 
tt.FontWeight = 'normal'; 
tt.Color = condcolor{icond};
[~,p] = ttest2(store_d{1}, store_d{2}, 'Vartype', 'unequal');
p = squeeze(p);
qvals = find(mafdr(p(:,icond), 'BHFDR', true)<pthres);
draw_sig(qvals, 0.95, siglw, chancecolor)
% plot(qvals,qvals*0+0.93+(icond-1)*0.035,'-','linewidth',siglw,'color',condcolor{icond})



dir_choice = {dir_v, dir_c};
cc = {1,2};
sd = 1.96;
for panel = 1:2
    liim = 20;
    x_ax = 2:liim;
    ax = subplot(2,4,3 + (3-panel-1)*4);
    for icond = cc{panel}
        store_d = cell(0);
        for whichgroup = [0, 1]
        idx = ToC(:,icond)==whichgroup;
        data = dir_choice{panel}(idx,:,:,:,:);
        store_d{whichgroup+1} = data(:,x_ax,icond);
        nsubj = size(data,1);
        hold on
        
        X_patch  = [x_ax, fliplr(x_ax)];
        yup      = mean(data(:,x_ax,icond),'omitnan') + ( std( data(:,x_ax,icond),'omitnan') / sqrt(nsubj)*sd ) ;
        ylo      = mean(data(:,x_ax,icond),'omitnan') - ( std( data(:,x_ax,icond),'omitnan') / sqrt(nsubj)*sd ) ;
        Y_patch  = [yup,flip(ylo)];
        fill(X_patch, Y_patch , 1, 'facecolor', 0.5*(col(icond,:)+1), 'edgecolor','none', 'facealpha', alpha*(whichgroup+1));
        plot(x_ax, mean(data(:,x_ax,icond),'omitnan'),lstyle{whichgroup+1}, 'Color', col(icond,:), 'LineWidth', lw(whichgroup+1));
        end
        [~,p] = ttest2(store_d{1}, store_d{2}, 'Vartype', 'unequal');
        p = squeeze(p);
        qvals = x_ax((mafdr(p, 'BHFDR', true)<pthres));
        draw_sig(qvals, 0.9, siglw, chancecolor)
        % plot(qvals,qvals*0+0.9+(icond-1)*0.035,'-','linewidth',siglw,'color',condcolor{icond})
    end
    xlabel('sampling trial')
    ylabel('p(policy-guided choice)');

    title_name = {'target guided','uncertainty guided'};
    tt = title(ax, title_name{panel}); 
    tt.FontWeight = 'normal'; 
    tt.Color = ones(1,3)*0.5;

    set(gca,'xtick',[2,seqLength],'xticklabelrotation',0,'ytick',[0.0,0.5,1])
    set(gca,'color','none','linewidth',1,'tickdir','out','fontsize',fs)
    ylim([0,1])
    xlim([0.5,inf])
    plot([0,20],[0.5,0.5],'--','LineWidth',1,'color',chancecolor)
    if panel==1
        text(16,0.8,'match','color',col(1,:),'FontSize',fs/1.2)
    end
end
text(16,0.62,'guess','color',col(2,:),'FontSize',fs/1.2)
if panel==2
    % text(8,0.87,'FDR p < 0.005','color',col(2,:),'FontSize',fs/1.2)
    text(2,0.85,'two-sided contrast','color',chancecolor,'FontSize',fs/1.2)
end

c = lines;
ax = subplot(2,4,8);
hold on;
icond=1;
whichgroup = 1;
h = [];
idx = ToC(:,icond)==whichgroup;
store_d = cell(0);
for k = 1:4
    store_d{1}(:,k) = pc_match{k}(idx,end);
end
for k = 1:4
    y = pc_match{k}(idx,end);
    nsubj = size(y,1);
    se = std(y)./sqrt(nsubj)*sd;
    h(1) = errorbar(seqLength(k),mean(y),se,'ko','markerfacecolor',c(4,:),...
        'markersize',ms,'linewidth',1,'CapSize',0);
end
whichgroup = 0;
idx = ToC(:,icond)==whichgroup;
for k = 1:4
    store_d{2}(:,k) = pc_match{k}(idx,end);
end
for k = 1:4
    y = pc_match{k}(idx,end);
    nsubj = size(y,1);
    se = std(y)./sqrt(nsubj)*sd;
    h(2) = errorbar(seqLength(k),mean(y),se,'o','markerfacecolor','w',...
    'markersize',ms,'linewidth',1,'CapSize',2,'color',c(4,:));
end    
set(gca,'color','none','box','off','FontSize',fs,'tickdir','out')
set(gca,'ytick',[0,0.5,0.9],'xtick',seqLength,'linewidth',1,'fontsize',fs)
ylim([0.45,0.9])
xlabel('sequence length')
ylabel('match accuracy')
xlim([0,20])
plot([1,20],[0.5,0.5],'--','linewidth',1,'color',chancecolor)
title_name = {'match','guess'};
tt = title(ax, title_name{icond}); 
tt.FontWeight = 'normal'; 
tt.Color = condcolor{icond};
legend(h,{'streaking','non-streaking'},'box','off','location','se','fontsize',fs)
[h,p,ci,stats] = ttest2(store_d{1}, store_d{2}, 'Vartype', 'unequal');
p = squeeze(p);
p_corr = Bonf_Holm_yc(p);
seq = [8 12 16 20];
fprintf('\nMATCH: two-sided Welch''s t-tests\n');
fprintf('Seq\t t\t df\t p_corr\n');
for i = 1:length(seq)
    fprintf('%d\t%.2f\t%.2f\t%.4f\n', ...
        seq(i), stats.tstat(i), stats.df(i), p_corr(i));
end
qvals = find(p_corr<0.05);
% text(seqLength(qvals),qvals*0+0.9,'*','color',guess,'LineWidth', 1)
text(seqLength(qvals),qvals*0+0.875,'*','HorizontalAlignment','Center',...
                'BackGroundColor','none','VerticalAlignment','middle',...
                'fontsize',16,'color',darkred)
[h,p,ci,stats] = ttest2(mean(store_d{1},2), mean(store_d{2},2), 'Vartype', 'unequal')

% stats:
seq = [8 12 16 20];
x1 = store_d{1}; x2 = store_d{2};
x1 = [x1, mean(x1,2)]; x2 = [x2, mean(x2,2)];   % last column = across-length mean

[~,p,~,stats] = ttest2(x1, x2, 'Vartype', 'unequal');
p = squeeze(p);
p_corr = p;
p_corr(1:4) = Bonf_Holm_yc(p(1:4));              % Holm only across the 4 lengths
d = (mean(x1,'omitnan') - mean(x2,'omitnan')) ./ ...
    sqrt((var(x1,'omitnan') + var(x2,'omitnan'))/2);

lab = [arrayfun(@num2str, seq, 'uni', 0), {'mean'}];
fprintf('\nMATCH: two-sided Welch''s t-tests\n');
fprintf('Seq\tt\tdf\td\tp\n');
for i = 1:numel(lab)
    fprintf('%s\t%.2f\t%.2f\t%.2f\t%.4f\n', lab{i}, stats.tstat(i), stats.df(i), d(i), p_corr(i));
end




ax = subplot(2,4,4);
hold on;
icond=2;
whichgroup = 1;
idx = ToC(:,icond)==whichgroup;
h = [];
store_d = cell(0);
for k = 1:4
    y = pc_guess(idx,k);
    store_d{1} = pc_guess(idx,:);
    nsubj = size(y,1);
    se = std(y)./sqrt(nsubj) * 1.96;
    h(1) = errorbar(seqLength(k),mean(y),se,'ko','markerfacecolor',c(5,:),...
        'markersize',ms,'linewidth',1,'CapSize',0);
end
whichgroup = 0;
idx = ToC(:,icond)==whichgroup;
for k = 1:4
    y = pc_guess(idx,k);
    store_d{2} = pc_guess(idx,:);
    nsubj = size(y,1);
    se = std(y)./sqrt(nsubj) * 1.96;
    h(2) = errorbar(seqLength(k),mean(y),se,'o','markerfacecolor','w',...
        'markersize',ms,'linewidth',1,'CapSize',2,'color',c(5,:));
end    
set(gca,'color','none','box','off','FontSize',fs,'tickdir','out')
set(gca,'ytick',[0,0.5,0.9],'xtick',seqLength,'linewidth',1,'fontsize',fs)
ylim([0.45,0.9])
xlabel('sequence length')
ylabel('guess accuracy')
xlim([0,20])
plot([1,20],[0.5,0.5],'--','linewidth',1,'color',chancecolor)
tt = title(ax, title_name{icond}); 
tt.FontWeight = 'normal'; 
tt.Color = condcolor{icond};
legend(h,{'streaking','non-streaking'},'box','off','location','se','autoupdate','off','fontsize',fs)

[h,p,ci,stats] = ttest2(store_d{1}, store_d{2}, 'Vartype', 'unequal');
p = squeeze(p);
p_corr = Bonf_Holm_yc(p);
seq = [8 12 16 20];
fprintf('\nGUESS: two-sided Welch''s t-tests\n');
fprintf('Seq\t t\t df\t p_corr\n');
for i = 1:length(seq)
    fprintf('%d\t%.2f\t%.2f\t%.4f\n', ...
        seq(i), stats.tstat(i), stats.df(i), p_corr(i));
end
qvals = find(p_corr < 0.05);
text(seqLength(qvals),qvals*0+0.888,'*','HorizontalAlignment','Center',...
                'BackGroundColor','none','VerticalAlignment','middle',...
                'fontsize',16,'color',darkred)
[h,p,ci,stats] = ttest2(mean(store_d{1},2), mean(store_d{2},2), 'Vartype', 'unequal');

% stats:
seq = [8 12 16 20];
x1 = store_d{1}; x2 = store_d{2};
x1 = [x1, mean(x1,2)]; x2 = [x2, mean(x2,2)];   % last column = across-length mean

[~,p,~,stats] = ttest2(x1, x2, 'Vartype', 'unequal');
p = squeeze(p);
p_corr = p;
p_corr(1:4) = Bonf_Holm_yc(p(1:4));              % Holm only across the 4 lengths
d = (mean(x1,'omitnan') - mean(x2,'omitnan')) ./ ...
    sqrt((var(x1,'omitnan') + var(x2,'omitnan'))/2);

lab = [arrayfun(@num2str, seq, 'uni', 0), {'mean'}];
fprintf('\nGUESS: two-sided Welch''s t-tests\n');
fprintf('Seq\tt\tdf\td\tp\n');
for i = 1:numel(lab)
    fprintf('%s\t%.2f\t%.2f\t%.2f\t%.4f\n', lab{i}, stats.tstat(i), stats.df(i), d(i), p_corr(i));
end


set(gcf, 'Renderer', 'painters'); %
set(gcf, 'PaperPositionMode', 'auto');



configALL;

% clc; close all;
c = elbo(:,:,1) - elbo(:,:,2);
x = c(:,1);
y = c(:,2);

array2table(sum(round(c)))

% Main scatter plot
% figure('Position',[168   302   405   378]);
figure('position',[420   274   250   535])
mainAx = axes('Position',[0.25, 0.25, 0.6, 0.6]);

col = lines;

plot(x(x>0&y>0), y(x>0&y>0), 'wo','MarkerSize',6,'MarkerFaceColor',col(1,:)); hold on;
plot(x(x>0&y<0), y(x>0&y<0), 'wo','MarkerSize',6,'MarkerFaceColor',col(2,:)); hold on;
plot(x(x<0&y>0), y(x<0&y>0), 'wo','MarkerSize',6,'MarkerFaceColor',col(3,:)); hold on;
plot(x(x<0&y<0), y(x<0&y<0), 'wo','MarkerSize',6,'MarkerFaceColor',col(6,:)); hold on;

% plot([0 0], ylim, 'k--');
plot(xlim, [0 0], 'k--');
xlabel('match \Delta ELBO','color',condcolor{1});
ylabel({'guess EoS: \Delta ELBO (free \theta - fixed \theta)'},'color',condcolor{2});
set(mainAx,'box','off','color','none','fontsize',fs,'xtick',[-10,0,10],'ytick',[-10,0,10])
set(mainAx,'linewidth',1)
% axis square

% Top histogram
topAx = axes('Position',[0.25, 0.85, 0.6, 0.1]);
histogram(topAx, x, 100,'FaceColor', [0.6 0.6 0.6]);
topAx.XAxis.Visible = 'off';
topAx.YAxis.TickDirection = 'out';
topAx.Box = 'off';
ylabel('count')

% Right histogram
rightAx = axes('Position',[0.85, 0.25, 0.1, 0.6]);
histogram(rightAx, y, 50,'Orientation', 'horizontal', 'FaceColor', [0.6 0.6 0.6]);
rightAx.YAxis.Visible = 'off';
rightAx.XAxis.TickDirection = 'out';
rightAx.Box = 'off';
xlabel('count')

% Link axes for proper alignment
linkaxes([mainAx, topAx], 'x');
linkaxes([mainAx, rightAx], 'y');

set(topAx,'box','off','color','none','fontsize',fs,'tickdir','out','linewidth',2)
set(rightAx,'box','off','color','none','fontsize',fs,'tickdir','out','linewidth',2)

hold on;
text(mainAx,-12,-6,num2str(sum(x<0 & y<0)),'color',col(6,:),'fontsize',fs)
text(mainAx,-12,+12,num2str(sum(x<0 & y>0)),'color',col(3,:),'fontsize',fs)
text(mainAx,+12,+12,num2str(sum(x>0 & y>0)),'color',col(1,:),'fontsize',fs)
text(mainAx,+12,-6,num2str(sum(x>0 & y<0)),'color',col(2,:),'fontsize',fs)

nBoot = 10000;
n = length(x);
bootCorr = zeros(nBoot,1);
for b = 1:nBoot
    idx = randi(n, n, 1);   % resample with replacement
    rho = corr(x(idx), y(idx), 'Type', 'Spearman');
    bootCorr(b) = rho;
end
% Point estimate and CI
rho_mean = mean(bootCorr);
ci = prctile(bootCorr, [2.5 97.5]);
fprintf('Bootstrap Spearman rho = %.3f, 95%% CI = [%.3f, %.3f]\n', ...
        rho_mean, ci(1), ci(2));
% Also compute observed Spearman correlation
rho_obs = corr(x, y, 'Type', 'Spearman');
fprintf('Observed Spearman rho = %.3f\n', rho_obs);

set(gcf, 'Renderer', 'painters'); %
set(gcf, 'PaperPositionMode', 'auto');

%%
clc;
% parameters
configALL;
p_name = {'\delta','\sigma','\beta_v','\beta_c','\beta_r','\theta','\epsilon'};
type = 1;
np = size(parameter,2);
figure('position',[258,641,820,400])
tiledlayout(2, np, 'TileSpacing', 'compact', 'Padding', 'compact');

% y range:
par = squeeze(parameter(:,:,type,:)); 
prange = [];
for p = np:-1:1
    pp = par(:,p,:);
    pp = pp(:);
    prange(p,:) = prctile(pp,[5,91]);
end
prange(1:6,1) = 0;
prange(7,1) = 0.5;
prange = round(prange,2);

for cond = 1:2
    np = size(parameter,2);
    for p = 1:np
        nexttile;
        datasave = cell(0);
        top = nan(1,2);
        if cond==2 && p==3
            % continue;
        end
        for g = 1:2
            idx = ToC(:,cond) == (2-g);
            est = parameter(idx,p,type,cond);
            datasave{g} = est;
            ns = length(est);
            se = std(est)/sqrt(ns) * 1.96;
            top(g) = mean(est)+se;

            if ~(cond==2 && p==3)
                if g==1
                    errorbar(g, mean(est), se, 'ko', 'markerfacecolor', condcolor{cond}, ...
                         'markersize', 6, 'linewidth', 1, 'CapSize', 0); 
                else
                    errorbar(g, mean(est), se, 'o', 'markerfacecolor', 'w', ...
                         'markersize', 6, 'linewidth', 1, 'CapSize', 2,'color',condcolor{cond}); 
                end
            end

           
            hold on;
            set(gca, 'box', 'off', 'color', 'none', 'tickdir', 'out', ...
                     'fontsize', fs, 'linewidth', 1)

            if p == 1 && cond == 2
                set(gca, 'xticklabel', {'streaking', 'non-streaking'}, ...
                         'XTickLabelRotation', 30, 'xtick', 1:2)
                ylabel('parameter estimate (a.u.)')
            else
                set(gca, 'xtick', [])
            end
            if cond==1
            title(p_name{p})
            end
            xlim([0.5, 3-0.5])
        end
        
        if cond==2 && p==3
            set(gca,'xcolor','none','ycolor','none')
        end

        ylim([prange(p,1), prange(p,2)])
        yt = get(gca, 'YTick');
        set(gca, 'YTick', [prange(p,1), prange(p,2)]);
        group1 = datasave{1};
        group2 = datasave{2};
        [~, pval, ~, stats] = ttest2(group1, group2, 'Vartype', 'unequal');
        fprintf('t(%g) = %.3f, p = %.4f\n', stats.df, stats.tstat, pval);

        if pval < 0.05
        t = max(top)*1.05;
        text(1.5,t,'*','HorizontalAlignment','Center',...
                'BackGroundColor','none','VerticalAlignment','middle',...
                'fontsize',16,'color',darkred); hold on;
        plot([1,2],[0,0]+t,'k-','LineWidth',1)
        end
    end
end
