clear;clc;close all;
rng(1234);

Nsim = 10; % simulations per participant and condition
dataset = 'COLINE';
% load human data;
load(['dat_choicestbl_',dataset,'.mat'],'choicestbl');
choicestbl(choicestbl.excludepart == true,:) = [];
data = choicestbl;
unique_ids = unique(data.subj);
nsubj = length(unique_ids);

load dat_modelparELBO_COLINE.mat

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Loop over each unique subject ID
type_name    = {'comleaknoise'};
nsmpMax      = 20;
seqLength    = [8,12,16,20];
nModel       = length(type_name);
drawEvi      = nan(nsubj,2,length(seqLength),3);
spstay_human = nan(nsubj,nsmpMax,2,1);
spstay_model = nan(nsubj,nsmpMax,2,nModel);
cfac         = 1.4386;
pSWh_byval   = cell(nsubj,2);              % human p(repeat), stored with its evidence value
pSWm_byval   = cell(nsubj,2,nModel,Nsim);  % model p(repeat), stored with its evidence value

for s = nsubj:-1:1
    subj_id = unique_ids(s);
    disp(['simulating subject #',num2str(s)])
    % Find files for this subject for each condition and model
    for cond = 1:2
        
        % get raw data
        irow = modelfit.subj==subj_id &...
        modelfit.("model(1=exact,2=leak,3=noise,4=leaknoise,5=leaknoiseNOthr)")==4 &...
        modelfit.("condition(1=bandit,2=guess)")==cond;
        out = modelfit(irow,:);

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

        cfg.same1st = false;
        cfg.shuffle = false;
        cfg.cfac    = cfac;
        
        seql  = cellfun(@(x)size(x,2),cfg.choices);
        nseq  = length(cfg.choices);
        
        type = 1;
        % take best-fit parameters: average of posterior
        betav   = out.betav;   % 0 for guess task
        betac   = out.betac;
        betar   = out.betar;
        theta   = out.theta;
        epsilon = out.epsilon;
        gamma   = out.gamma;   % fixed: 0.1
        delta_c = out.deltac;   % leak chosen
        delta_u = out.deltau;   % leak unchosen
        sigma = out.sigma;   % inference noise

        parameter(s,:,type,cond) = [delta_c,delta_u,sigma,betav,betac,betar,theta,epsilon];
        elbo(s,cond,type,:) = out.elbo;

        for isim = 1:Nsim
            [mch,~,mfq] = sim_modelbound_noisyleaky(betav,betac,betar,theta,epsilon,gamma,delta_c,delta_u,sigma,cfg);
        
            %%%%%%%%%%%%%%%%%%%%%%%%
            % fraction repeat (model)
            %%%%%%%%%%%%%%%%%%%%%%%%
            sprevch  = nan(nseq,nsmpMax);
            srepeat  = nan(nseq,nsmpMax);
            for iseq = 1:nseq
                ch = mch{iseq};
                nsmp = numel(ch);
                for ismp = 1:nsmp-1
                    sprevch(iseq,ismp) = sum(ch(1:ismp)==ch(ismp));
                    srepeat(iseq,ismp) = ch(ismp)==ch(ismp+1);
                end
            end
            for idx = 1:max(max(sprevch))
                ich = find(sprevch==idx);
                spstay_model(s,idx,cond,type,isim) = mean(srepeat(ich),'omitnan');
            end
    
            % policyguided
            mvopt = cell(0); mcopt = cell(0);
            psw = [];
            for iseq = 1:nseq
                ch = mch{iseq};
                c  = cfg.colorop{iseq}';
                ntrl = length(ch);
                for trl = 1:ntrl
                    unchosen = 3-ch(trl);
                    c(trl,unchosen) = nan;
                end
                c  = c*cfac;
                xc = zeros(size(c,1),2);
                xc(2:end,:) = cumsum(c(1:end-1,:),1,'omitnan');
                
                [~, tempopt]  = max(xc*cfg.targetc(iseq),[],2);
                mvopt{iseq,1} = [ch==tempopt' nan(1,20-size(ch,2))];
                mvopt{iseq,1}(xc(:,1)==xc(:,2)) = nan; % if options are equal, nan
    
                [~, tempopt] = min(abs(xc),[],2);
                mcopt{iseq,1}  = [ch==tempopt' nan(1,20-size(ch,2))];
                mcopt{iseq,1}(abs(xc(:,1))==abs(xc(:,2))) = nan; % if options are equal, nan
    
                prior = xc;
                chosen_prior = [];
                for trl = 1:size(prior,1)
                    chosen_prior(trl,1) = prior(trl,ch(trl));
                end
                chosen_evi = sum(c,2,'omitnan');
                belief_aligned_evi = chosen_evi .* sign(chosen_prior);
                target_aligned_evi = cfg.targetc(iseq) * chosen_evi;
                p_switch_next = [ch(2:end)~=ch(1:end-1),nan]';
                if cond==1
                    signed_evi = target_aligned_evi;
                else
                    signed_evi = belief_aligned_evi;
                end
                psw = [psw; signed_evi, p_switch_next];
    
            end
            dir_c_model(s,:,cond,type,isim) = mean(cell2mat(mcopt),1,'omitnan');
            dir_v_model(s,:,cond,type,isim) = mean(cell2mat(mvopt),1,'omitnan');
    
            % bin:
            rmv = psw(:,1)==0 | isnan(psw(:,2));
            psw(rmv, :) = [];
            psw = round(psw, 5);
            evi_level = unique(psw(:,1));
            % for lev_i = 1:length(evi_level)
            %     pSW_model(s,lev_i,cond,type,isim) = 1-mean(psw(psw(:,1)==evi_level(lev_i), 2));
            % end
            % store p(repeat) with its evidence value; columns are aligned by value after the subject loop
            pSWm_byval{s,cond,type,isim} = [evi_level, arrayfun(@(v) 1-mean(psw(psw(:,1)==v,2)), evi_level)];

        end % sim end

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
            spstay_human(s,idx,cond) = mean(srepeat(ich),'omitnan');
        end

        % policy-guided
        mvopt = cell(0); mcopt = cell(0);
        psw = [];
        for iseq = 1:nseq
            ch = cfg.choices{iseq};
            c  = cfg.colvals{iseq}';
            c  = c*cfac;
            xc = zeros(size(c,1),2);
            xc(2:end,:) = cumsum(c(1:end-1,:),1,'omitnan');
            
            [~, tempopt]  = max(xc*cfg.targetc(iseq),[],2);
            mvopt{iseq,1} = [ch==tempopt' nan(1,20-size(ch,2))];
            mvopt{iseq,1}(xc(:,1)==xc(:,2)) = nan; % if options are equal, nan

            [~, tempopt] = min(abs(xc),[],2);
            mcopt{iseq,1}  = [ch==tempopt' nan(1,20-size(ch,2))];
            mcopt{iseq,1}(abs(xc(:,1))==abs(xc(:,2))) = nan; % if options are equal, nan

            prior = xc;
            chosen_prior = [];
            for trl = 1:size(prior,1)
                chosen_prior(trl,1) = prior(trl,ch(trl));
            end
            chosen_evi = sum(c,2,'omitnan');
            belief_aligned_evi = chosen_evi .* sign(chosen_prior);
            target_aligned_evi = cfg.targetc(iseq) * chosen_evi;
            p_switch_next = [ch(2:end)~=ch(1:end-1),nan]';
            if cond==1
                signed_evi = target_aligned_evi;
            else
                signed_evi = belief_aligned_evi;
            end
            psw = [psw; signed_evi, p_switch_next];
        end
        dir_c_human(s,:,cond) = mean(cell2mat(mcopt),1,'omitnan');
        dir_v_human(s,:,cond) = mean(cell2mat(mvopt),1,'omitnan');
        % bin:
        rmv = psw(:,1)==0 | isnan(psw(:,2));
        psw(rmv, :) = [];
        psw = round(psw, 5);
        evi_level = unique(psw(:,1));
        % for lev_i = 1:length(evi_level)
        %     pSW_human(s,lev_i,cond) = 1-mean(psw(psw(:,1)==evi_level(lev_i), 2));
        % end
        % store p(repeat) with its evidence value; columns are aligned by value after the subject loop
        pSWh_byval{s,cond} = [evi_level, arrayfun(@(v) 1-mean(psw(psw(:,1)==v,2)), evi_level)];
        
    end % cond
end % sub

% align p(repeat) across participants and simulations by evidence value, not by position:
% fix the reference levels once, pre-fill with NaN, place each value in its matching column
lev_all   = cellfun(@(x) x(:,1), [pSWh_byval(:); pSWm_byval(:)], 'UniformOutput', false);
evi_level = unique(vertcat(lev_all{:}));
pSW_human = nan(nsubj, numel(evi_level), 2);
pSW_model = nan(nsubj, numel(evi_level), 2, nModel, Nsim);
for isub = 1:nsubj
    for icnd = 1:2
        [~, lev_loc] = ismember(pSWh_byval{isub,icnd}(:,1), evi_level);
        pSW_human(isub,lev_loc,icnd) = pSWh_byval{isub,icnd}(:,2)';
        for ityp = 1:nModel
            for jsim = 1:Nsim
                [~, lev_loc] = ismember(pSWm_byval{isub,icnd,ityp,jsim}(:,1), evi_level);
                pSW_model(isub,lev_loc,icnd,ityp,jsim) = pSWm_byval{isub,icnd,ityp,jsim}(:,2)';
            end
        end
    end
end
fprintf('Signed-evidence levels: %d\n', numel(evi_level));

%%%%%%

clc;close all;
configALL;
size(dir_v_model);
size(dir_c_model);
size(spstay_model);
size(pSW_model);

patchcolor = [condcolor{1}; condcolor{2}];
cfg = [];

tmp1 = mean(dir_v_model(:,2:end,1,:,:),5,'omitnan');
tmp2 = mean(dir_c_model(:,2:end,:,:,:),5,'omitnan');
tmp3 = mean(spstay_model(:,1:10,:,:,:),5,'omitnan');
tmp4 = mean(pSW_model(:,:,:,:,:),5,'omitnan');

data = {tmp1,tmp2,tmp3,tmp4};
xvalue = {2:20, 2:20, 1:10, evi_level'};
yrange = {[0,1],[0,1],[0.5,1],[0.5,1],};

data_human = {dir_v_human(:,2:end,1),dir_c_human(:,2:end,:),spstay_human(:,1:10,:),pSW_human};

figure('position',[420   274   800   220])
tiledlayout(1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:4
    nexttile;

    m = squeeze(mean(data_human{i},1,'omitnan'));
    % se = squeeze(std(data_human{i},1,'omitnan')/sqrt(nsubj)*1.96);
    se = squeeze(std(data_human{i},'omitnan')/sqrt(nsubj)*1.96);   % default normalization (N-1)
    if size(m,1)<2, m = m'; se = se'; end
    for k = 1:size(m,2)
        errorbar(xvalue{i},m(:,k),se(:,k),'o','markerfacecolor',ones(1,3)*0.8,...
        'markersize',5,'linewidth',1,'CapSize',0,'color',patchcolor(k,:)); hold on
    end

    cfg.plotdots  = false;
    cfg.plotline  = true;
    cfg.shading   = true;
    cfg.linewidth = 1.5;
    cfg.alpha     = alpha;
    hold on;
    plotpatch(data{i},xvalue{i},patchcolor,cfg);
    
    if i==1 || i==2
        plot([0,20],[0.5,0.5],'k--','linewidth',1);
        ylim([0,1]); 
        xlim([1,20])
        xtick = [2,8,12,16,20];
        set(gca,'xtick',xtick,'ytick',0:0.5:1,'xticklabel',xtick,'xticklabelrotation',0)
    end
    if i==4
        plot([0,0],[0.5,1],'k--','linewidth',1);
        ylim([0.5,1]);
        liim = length(evi_level);
        xtick = round(evi_level([1,3,6,liim]),1);
        of = 0.02;
        xlim([-1.48-of,1.48+of])
        set(gca,'xtick',xtick,'ytick',0.5:0.25:1,'xticklabel',xtick,'xticklabelrotation',0)
    end
    if i==3
        xtick = [1,4,7,10];
        set(gca,'xtick',xtick,'ytick',0.5:0.25:1)
        xlim([0.5,10])
    end

    xlabnames = {'sampling trial','sampling trial','times seen before','signed evidence (logLR)'};
    ylabnames = {'p(policy-guided choice)','p(policy-guided choice)','p(repeat next)','p(repeat next)'};
    xlabel(xlabnames{i})
    ylabel(ylabnames{i})

    set(gca,'color','none','linewidth',1,'tickdir','out','fontsize',fs,'box','off')
    ylim(yrange{i})

    if i==1
    h = [];
    h(1)=errorbar(xvalue{i},m(:,k)*0-10,se(:,k),'o','markerfacecolor',ones(1,3)*0.8,...
        'markersize',5,'linewidth',1,'CapSize',0,'color','k'); hold on
    h(2)=plotpatch(data{i}(:,:,1)*0+10,xvalue{i},ones(1,3)*0.2,cfg);
    legend(h,{'human','model'},'location','sw','color','none','box','off')
    end

    fs_t = fs/1.2;
    if i==1
        text(17,0.8,'match','color',match,'FontSize',fs_t,'HorizontalAlignment', 'center')
        title_name = {'target guided','uncertainty guided'};
        t = title(title_name{1}); 
        t.FontWeight = 'normal';  % remove bold
        t.Color = ones(1,3)*0.5;
    end


    if i==2
        text(17,0.26,'match','color',match,'FontSize',fs_t,'HorizontalAlignment', 'center')
        text(17,0.66,'guess','color',guess,'FontSize',fs_t,'HorizontalAlignment', 'center')
        title_name = {'target guided','uncertainty guided'};
        t = title(title_name{2}); 
        t.FontWeight = 'normal';  % remove bold
        t.Color = ones(1,3)*0.5;
    end

    if i==3
        text(9,0.85,'match','color',match,'FontSize',fs_t,'HorizontalAlignment', 'center')
        text(9,0.63,'guess','color',guess,'FontSize',fs_t,'HorizontalAlignment', 'center')
    end

    if i==4
        text(1,0.9,'match','color',match,'FontSize',fs_t,'HorizontalAlignment', 'center')
        text(1,0.6,'guess','color',guess,'FontSize',fs_t,'HorizontalAlignment', 'center')
    end

end

set(gcf, 'Renderer', 'painters'); %
set(gcf, 'PaperPositionMode', 'auto');


% model parameters:
col = lines;
cfg      = [];
cfg.markersize = 20;
cfg.color = col(4:5,:);

cfg.noiseSD = 4;
cfg.dotalpha = 0.05;
cfg.CItype = 0;
cfg.side = 'both';
p_name = {'\delta','\sigma','\beta_v','\beta_c','\beta_r','\theta','\epsilon'};

type = 1;
np = size(parameter,2);
idx = [1,3:np];
input = squeeze(parameter(:,idx,type,:));
figure('position',[258,641,800,400])
np = size(input,2);
tiledlayout(2, np, 'TileSpacing', 'compact', 'Padding', 'compact');
for i = 1:np
    nexttile;
    data = squeeze(input(:,i,:));
    yl = prctile(data(:),[2.5,97.5]);
    
    if min(data(:))>=0, yl(1) = -0.05;end
    if max(data(:))==1, yl(2) = 1+0.2;end
    
    if i==1,  yl = [-0.01,0.6];end
    if i==np, yl = [-0.01,1.05];end

    if i>=3 && i<=5
        yl = [-1, 3];
    end
    
    cfg.sigy = yl(2)*0.99;
    cfg.starcolor = darkred;
    cfg.conn = 1;
    if i==3
        cfg.conn = 0;
    end
    % asterisks here are for display only; inference uses the max-T permutation tests below
    draw_dataDistCI(data,cfg);
    set(gca,'box','off','color','none','tickdir','out','fontsize',fs,'linewidth',1)
    title(p_name{i})
    plot([-10,10],[0,0],'k--');
    xlim([0.5,3-0.5])
    ylim(yl)
    if i==1
        set(gca,'xticklabel',{'match','guess'},'XTickLabelRotation',30,'xtick',1:2)
        ylabel('parameter estimate (a.u.)')
    else
        set(gca,'xtick','')
    end
end


corr_type = 'spearman';
nboot = 10000;

% Console report of the Fig. 4c bootstrap statistics
pname_txt = {'leak (delta)','noise (sigma)','beta_v','beta_c','beta_r','theta','epsilon'};
if strcmp(corr_type,'spearman'), cm_txt = 'rho'; else, cm_txt = 'r'; end
fprintf('\nFig. 4c: match vs guess correlation of parameters (%s, %d bootstrap resamples, n = %d)\n', ...
    corr_type, nboot, size(input,1));
for i = 1:np
    nexttile;
    data = squeeze(input(:,i,:));

    if i~=3
    scatter(data(:,1),data(:,2), 30, 'filled',...
            'markerfacecolor', ones(1,3)*0.5,...
            'MarkerEdgeColor', 'w', ...
            'MarkerFaceAlpha', 0.2, ... % Set alpha transparency for marker face
            'MarkerEdgeAlpha', 0.2)
    hold on
    axis square
    lims = [min(data(:)), max(data(:))];  % axis limits covering both x and y
    plot(lims, lims, 'k--')  % diagonal x = y
    end
    %%%%%%%%%%%%%% boostrap 
    x = data(:,1); y = data(:,2);
   
    n = length(x);
    
    r_boot = nan(nboot,1);
    for j = 1:nboot
        idx = randsample(n, n, true);  % sample with replacement
        xi = x(idx);
        yi = y(idx);
        r_boot(j) = corr(xi, yi, 'type', corr_type);
    end
    ci = prctile(r_boot, [2.5 97.5]);
    psig = '';
    if ci(1)>0 || ci(2)<0, psig = '*'; end
    % Compute basic stats
    mu_x = mean(x);
    mu_y = mean(y);
    std_x = std(x);
    std_y = std(y);
    % Generate x grid for fit
    xc = x(:);
    xc(xc<prctile(xc,0.1) | xc>prctile(xc,99.9)) = [];
    x_fit = linspace(min(xc), max(xc), 100);
    
    % Create matrix of fitted y values across bootstrap samples
    y_boot = nan(length(r_boot), length(x_fit));
    for j = 1:length(r_boot)
        slope_i = r_boot(j) * (std_y / std_x);
        intercept_i = mu_y - slope_i * mu_x;
        y_boot(j, :) = intercept_i + slope_i * x_fit;
    end

    % Compute confidence bounds
    y_lower = prctile(y_boot, 2.5);
    y_upper = prctile(y_boot, 97.5);
    % Plot mean fit line
    r_mean = mean(r_boot);
    % Two-sided bootstrap P: twice the smaller tail proportion of r_boot on either side of zero
    p_boot = min(1, 2*min(mean(r_boot <= 0), mean(r_boot >= 0)));
    if i ~= 3   % beta_v exists in the match condition only
        if p_boot < 0.001, p_txt = 'P < 0.001'; else, p_txt = sprintf('P = %.3f', p_boot); end
        fprintf('  %-14s %s = %.3f, 95%% CI [%.3f, %.3f], two-sided bootstrap %s\n', ...
            pname_txt{i}, cm_txt, r_mean, ci(1), ci(2), p_txt);
    end
    slope = r_mean * (std_y / std_x);
    intercept = mu_y - slope * mu_x;
    y_fit = intercept + slope * x_fit;

    set(gca,'color','none','linewidth',1,'box','off','tickdir','out')
    set(gca,'fontsize',fs)

     switch corr_type
        case 'pearson'
            corr_mark = 'r';
        case 'spearman'
            corr_mark = '\rho';
    end
    
    set(gca,'color','none','linewidth',1,'box','off','tickdir','out')
    set(gca,'fontsize',fs)
    if i==1
        xlabel('match')
        ylabel('guess')
    end

    if ~(i==3)
    title(sprintf('%s = %.2f%s\nCI: %.2f–%.2f', corr_mark, r_mean, psig, ci(1), ci(2)), ...
        'FontWeight', 'normal', 'FontSize', fs/1.1)
    end

    clear xticks yticks
    ax = gca;  % get current axes
    % X-axis
    xt = get(ax, 'XTick');
    if numel(xt) > 3
        xt = linspace(min(xt), max(xt), 3);
        xticks(xt);
    end
    % Y-axis
    yt = get(ax, 'YTick');
    if numel(yt) > 3
        yt = linspace(min(yt), max(yt), 3);
        yticks(yt);
    end

    if i==3
        set(gca,'xcolor','none','ycolor','none')
    end

end

set(gcf, 'Renderer', 'painters'); %
set(gcf, 'PaperPositionMode', 'auto');

%%
% permutation test for match vs. guess contrast:
D4perm = input(:,[1,2,4,5,6,7],:); % ignore betav;
% X is nSubj x nParam x 2
res = perm_paired_maxT(D4perm, 10000, 0.05, 'both');
% print a quick table
p_unc_str  = arrayfun(@(x) sprintf('%.10f', x), res.p_unc, 'UniformOutput', false);
p_corr_str = arrayfun(@(x) sprintf('%.10f', x), res.p_corr, 'UniformOutput', false);
T = table((1:numel(res.t_obs))', res.t_obs', res.dz', p_unc_str', p_corr_str', res.h', ...
    'VariableNames', {'param','t','dz','p_unc','p_corr','sig'});
disp(T)
betas = input(:,[3,4,5],:);
[h,p,~,st] = ttest(betas);
squeeze(st.tstat);

%%
betas = input(:, [3 4 5], :);
B     = [betas(:,:,1), betas(:,[2 3],2)];        % 420 x 5 valid tests
names = {'reg3_cond1','reg4_cond1','reg5_cond1','reg4_cond2','reg5_cond2'};

nPerm = 10000;                                  % smallest attainable P = 1/(nPerm+1), about 1e-4
rng(1);
[pFWE, tObs] = maxT_signflip(B, nPerm);

disp(table(tObs, pFWE, 'RowNames', names));
nSub   = size(B, 1);
m      = mean(B, 1)';
sd     = std(B, 0, 1)';
cohend = m ./ sd;
tcrit  = tinv(0.975, nSub - 1);
ci     = [m - tcrit * sd / sqrt(nSub), m + tcrit * sd / sqrt(nSub)];

for k = 1:numel(names)
    % if pFWE(k) < 0.0001
    %     pstr = 'P_FWE < 0.0001';
    % elseif pFWE(k) < 0.001
    %     pstr = 'P_FWE < 0.001';
    % else
    if pFWE(k) < 0.001   % APA: exact P to 3 decimals, "P < 0.001" below 0.001
        pstr = 'P_FWE < 0.001';
    else
        pstr = sprintf('P_FWE = %.3f', pFWE(k));
    end
    fprintf('%s: mean = %.3f, 95%% CI = [%.3f, %.3f]; t(%d) = %.2f, %s, Cohen''s d = %.3f\n', ...
        names{k}, m(k), ci(k,1), ci(k,2), nSub - 1, tObs(k), pstr, cohend(k));
end

function [pFWE, tObs] = maxT_signflip(B, nPerm)
% One-sample t-test against 0 for each column of B (subjects x tests),
% FWE-corrected across columns with a max-|t| sign-flip permutation test.
    nSub = size(B, 1);
    tfun = @(X) mean(X, 1) ./ (std(X, 0, 1) ./ sqrt(nSub));

    tObs = tfun(B)';
    maxNull = zeros(nPerm, 1);
    for k = 1:nPerm
        s = sign(rand(nSub, 1) - 0.5);
        maxNull(k) = max(abs(tfun(B .* s)));
    end
    pFWE = (sum(maxNull >= abs(tObs)', 1)' + 1) / (nPerm + 1);
    pFWE(isnan(tObs)) = NaN;
end