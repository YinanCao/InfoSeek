clear;clc;close all;
rng(1234);

Nsim = 10; % simulations per participant, condition and knockout type
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
type_name    = {'comleaknoise'};
nsmpMax      = 20;
seqLength    = [8,12,16,20];
cfac         = 1.4386;

for s = nsubj:-1:1
    subj_id = unique_ids(s);
    
    % Find files for this subject for each condition and model
    for cond = 1:2

        fprintf('*** subj=%d, cond=%d *** \n', subj_id, cond);
        
        % get raw data
        if cond==1 % match
            iseq = find(data.subj == subj_id & data.condition == cond & data.counterfactual==1);
        else
            iseq = find(data.subj == subj_id & data.condition == cond);
        end
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

        cfg.same1st = true;
        cfg.shuffle = false;
        cfg.cfac    = cfac;

        % take comleaknoise model
        bestparm = M(M(:,1)==subj_id & M(:,2)==cond & M(:,3)==4, 5:13);

        %%%% elbo %%%%%%%%%%%%%%
        for whichmodel = 1:4
            gof = M(M(:,1)==subj_id & M(:,2)==cond & M(:,3)==whichmodel, 4);
            elbo(s,cond,whichmodel,:) = gof;
        end

        seql  = cellfun(@(x)size(x,2),cfg.choices);
        nseq  = length(cfg.choices);

        for type = 1:4 % different knockout of variability source
            
            delta_c = bestparm(1);   % leak chosen
            delta_u = bestparm(2);   % leak unchosen
            sigma   = bestparm(3);   % inference noise
            betav   = bestparm(4);   % 0 for guess task
            betac   = bestparm(5);
            betar   = bestparm(6);
            theta   = bestparm(7);
            epsilon = bestparm(8);
            gamma   = bestparm(9);   % fixed: 0.1

            % knock-out
            if type==1 % noise=0, leak=0
                sigma = 0; 
                delta_c = 0;
                delta_u = 0;
                sigma_sel = 0;
            end

            if type==2 % noise=0, leak>0
                sigma = 0; 
                sigma_sel = 0;
            end

            if type==3 % leak=0, noise>0
                delta_c = 0;
                delta_u = 0;
                sigma_sel = 0;
            end

            psim = [];
            LLR = [];
            for isim = 1:Nsim
                pcorr = [];
                [mch,~,mfq] = sim_modelbound_noisyleaky(betav,betac,betar,theta,epsilon,gamma,delta_c,delta_u,sigma,cfg);
                if cond==1 % match
                    for iseq = 1:nseq
                        pcorr(iseq,1) = double(mch{iseq}(end)==1);
                    end
                else
                    mfq = mfq + randn(size(mfq))*sigma_sel;
                    pcorr = double(mfq > 0);
                    pcorr(isnan(mfq)) = nan;
                    pcorr(mfq==0) = 0.5;
                end
                psim(:,:,isim) = pcorr;
                LLR(:,isim) = mfq;
            end
            pFinal = mean(psim,3); % avg across iter

            if cond==2 % guess task
                if type==1
                    guessPc_human(s,:) = arrayfun(@(l)mean(guesspc(seql==l)),seqLength);
                end
                guessPc_model(s,:,type) = arrayfun(@(l)mean(pFinal(seql==l)),seqLength);
            end

            if cond==1
                if type==1
                    drawpc = []; % human
                    for iseq = 1:nseq
                        drawpc(iseq,1) = double(choices{iseq}(end)==1);
                    end
                    drawPc_human(s,:) = arrayfun(@(l)mean(drawpc(seql==l)),seqLength);
                end
                drawPc_model(s,:,type) = arrayfun(@(l)mean(pFinal(seql==l)),seqLength);
            end

        end % model type
    end % cond
end % sub

%% model comparison
disp('running model comparison....')
elbo_run = elbo(:,:,1:4);
[ns,ncond,nmodel] = size(elbo_run);
% run Bayesian model selection in each condition
pavg_mod = nan(ncond, nmodel);  % prevalence
pstd_mod = nan(ncond, nmodel);  % prevalence s.d.
pexc_mod = nan(ncond, nmodel);  % exceedance probabilities
alphas   = nan(ncond, nmodel);  % alphas of the Drch distributions
credint_lower = nan(ncond, nmodel);
credint_upper = nan(ncond, nmodel);
bor = [];
for icond = 1:ncond
    lme = squeeze(elbo_run(:,icond,:));
    % run BMS
    [alpha,~,pexc,xpexc,bor(icond)] = spm_BMS(lme);
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
end
% pavg_mod
% pexc_mod
% bor

% factorial
pavg_mod_fac = nan(ncond, 2);
credint_lower_fac = nan(ncond, 2);
credint_upper_fac = nan(ncond, 2);
for icond = 1:2
    lme = squeeze(elbo_run(:, icond, :));
    [alpha,~,pexc,xpexc] = spm_BMS(lme);
    % family definitions
    family_leak.names     = {'no leak','leak'};
    family_leak.partition = [1 2 1 2];
    family_leak.infer     = 'RFX';
    family_noise.names     = {'no noise','noise'};
    family_noise.partition = [1 1 2 2];
    family_noise.infer     = 'RFX';
    % BMS family
    [family_leak_out, model_leak_out] = spm_compare_families(lme, family_leak);
    [family_noise_out, model_noise_out] = spm_compare_families(lme, family_noise);
    % point estimate
    pavg_mod_fac(icond,:) = [family_leak_out.exp_r(2), family_noise_out.exp_r(2)];
    % sample from Dirichlet
    samples = drchrnd(alpha, nsamples); % nsamples × 4
    % group samples to families
    leak_family_probs  = [samples(:,1) + samples(:,3), samples(:,2) + samples(:,4)];
    noise_family_probs = [samples(:,1) + samples(:,2), samples(:,3) + samples(:,4)];
    % quantiles for 95% credible intervals
    leak_q025 = quantile(leak_family_probs(:,2), 0.025);
    leak_q975 = quantile(leak_family_probs(:,2), 0.975);
    noise_q025 = quantile(noise_family_probs(:,2), 0.025);
    noise_q975 = quantile(noise_family_probs(:,2), 0.975);
    % store
    credint_lower_fac(icond,:) = [leak_q025, noise_q025];
    credint_upper_fac(icond,:) = [leak_q975, noise_q975];
end
disp('done')

%% figure

close all; clc
figure('position',[420   274   780   464])

configALL;

col = [];
c = lines;
col(1,:) = [0,0,0];% exact
col(2,:) = c(2,:); % leak
col(3,:) = c(6,:); % noise learn
col(4,:) = c(7,:); % leak+noise
col(5,:) = c(1,:); % noise select 

guess    = c(5,:); % human
match   = c(4,:);
humancolor = {match, guess};

tiledlayout(2, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
for icond = 1:2
    ax = nexttile;
    t = 0.2*ones(1,nmodel);
    for k = 1:nmodel
        c = col(k,:);
        b = bar(k,pavg_mod(icond,k),...
            'FaceColor',c,'EdgeColor',c,'linewidth',1.5);
        b.FaceAlpha = t(k);
        b.EdgeAlpha = t(k)*2;
        hold on
        errorbar(k, pavg_mod(icond,k), ...
             pavg_mod(icond,k) - credint_lower(icond,k), ...
             credint_upper(icond,k) - pavg_mod(icond,k), ...
             'color', c, 'linewidth', 1.5, 'CapSize', 0);
        set(ax, 'box', 'off', ...
            'color', 'none', ...
            'tickdir', 'out', ...
            'fontsize', fs, ...
            'XTick', [],'linewidth',1,'ytick',[0,0.5,1]);
        ylim(ax, [0, 1.05]);
        ylabel(ax, 'model prevalence');
        xlabel(ax,'model')
    end

    xt = 1:nmodel;
    name = {'exact','leak','noise','leak + noise'};
    if icond==1
        for i = 1:length(xt)
            text(xt(i), 0.1, name{i}, ...
             'HorizontalAlignment', 'left', 'Rotation', 90, ...
             'VerticalAlignment', 'middle',...
             'Color',col(i,:), 'FontSize', 16);
        end
    end

    if icond==2
        for i = 3
            text(xt(i), 0.1, name{i}, ...
             'HorizontalAlignment', 'left', 'Rotation', 90, ...
             'VerticalAlignment', 'middle',...
             'Color',col(i,:), 'FontSize', 16);
        end
    end

    if icond==1
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
        xlim([0,5])
    end

    if icond==2
        chance = 1/nmodel;
        bw = b.BarWidth;
        plot([-10, 2 + bw/2], [chance chance],'-','color', chancecolor, 'linewidth', 1);
        % draw between bars
        for k = 2:(nmodel-1)
            right_edge = k + bw/2;
            next_left = (k+1) - bw/2;
            plot([right_edge next_left], [chance chance], 'color', chancecolor, 'linewidth', 1);
        end
        % draw after last bar
        last_right = nmodel + bw/2;
        plot([last_right 10], [chance chance], 'color', chancecolor, 'linewidth', 1);
        xlim([0,5])
    end

    pexc = pexc_mod(icond,:);
    [~,k] = max(pexc);

    yp = credint_upper(icond,k)+0.02;
    plot(1:nmodel,ones(1,nmodel)*yp,'color','k')
    plot([k,k],[yp,yp-0.01],'color','k')
    % Pexc label from the computed protected exceedance probability
    pmax = max(pexc);
    if pmax > 0.99
        ptxt = 'P\rmexc > 0.99';
    else
        ptxt = sprintf('\\itP\\rmexc = %.2f', pmax);
    end
    fprintf('Protected exceedance probability of the winning model (cond %d): %.4f\n', icond, pmax);
    if icond==1
        % text(1, yp-0.05, '\itP\rmexc > .99');  (original)
        text(1, yp-0.05, ptxt);
    else
        % text(1, yp+0.05, '\itP\rmexc > .99');  (original)
        text(1, yp+0.05, ptxt);
    end

    title_name = {'match','guess'};
    tt = title(ax, title_name{icond}); 
    tt.FontWeight = 'normal';
    tt.Color = humancolor{icond};

    ax = nexttile;
    for k = 1:2
        c = col(k+1,:);
        b = bar(k,pavg_mod_fac(icond,k),...
            'FaceColor',c,'EdgeColor',c,'linewidth',1.5);
        b.FaceAlpha = t(k);
        b.EdgeAlpha = t(k)*2;
        hold on
        errorbar(k, pavg_mod_fac(icond,k), ...
             pavg_mod_fac(icond,k) - credint_lower_fac(icond,k), ...
             credint_upper_fac(icond,k) - pavg_mod_fac(icond,k), ...
             'color', c, 'linewidth', 1.5, 'CapSize', 0);
        set(ax, 'box', 'off', ...
            'color', 'none', ...
            'tickdir', 'out', ...
            'fontsize', fs, ...
            'XTick', [],'linewidth',1,'ytick',[0,0.5,1]);
        ylim(ax, [0, 1]);
        ylabel(ax, 'factor prevalence');
        xlabel(ax,'model family')
    end

    xt = 1:2;
    yt = ylim;
    names = {'leak vs. no leak','noise vs. no noise'};
    if icond==1
        for i = 1:length(xt)
            text(xt(i), 0.1, names{i}, ...
                 'HorizontalAlignment', 'left', 'Rotation', 90, ...
                 'VerticalAlignment', 'middle',...
                 'Color',col(i+1,:), 'FontSize', 16);
        end
    end

    if icond==2
        for i = 2
            text(xt(i), 0.1, names{i}, ...
                 'HorizontalAlignment', 'left', 'Rotation', 90, ...
                 'VerticalAlignment', 'middle',...
                 'Color',col(i+1,:), 'FontSize', 16);
        end
    end

    title_name = {'match','guess'};
    tt = title(ax, title_name{icond}); 
    tt.FontWeight = 'normal';
    tt.Color = humancolor{icond};

    chance = 1/2;
    bw = b.BarWidth;
    if icond==1
        first_left = 1 - bw/2;
    else
        first_left = 2 - bw/2;
    end
    % plot(first_left,0.5,'o')
    plot([-10, first_left], [chance chance],'-','color', chancecolor, 'linewidth', 1);
    % draw between bars
    for k = 1:(2-1)
        right_edge = k + bw/2;
        next_left = (k+1) - bw/2;
        plot([right_edge next_left], [chance chance], 'color', chancecolor, 'linewidth', 1);
    end
    % draw after last bar
    last_right = 2 + bw/2;
    hold on
    % plot(last_right,0.5,'o')
    plot([last_right, 100], [chance chance],'-', 'color', chancecolor, 'linewidth', 1);
    xlim([0,3])

    %%%%%%%%%%%%%% ex-post simulation prediction
    if icond==2, acc_human = guessPc_human; acc_model = guessPc_model; end
    if icond==1, acc_human = drawPc_human; acc_model = drawPc_model; end
    ci = std(acc_human)./sqrt(nsubj)*1.96;

    ybtm = 0.5;
    ytop = 1.0;

    tracecolor = col;

    cfg           = [];
    cfg.linewidth = 2;
    cfg.alpha     = alpha;
    cfg.plotdots  = 0;
    cfg.doSE      = 0;

    nexttile;
    h = [];
    for i = 4
        cfg.plotdots = 0;
        h(1) = plotpatch(acc_model(:,:,i),seqLength,tracecolor(i,:),cfg);
    end
    h(2) = errorbar(seqLength,mean(acc_human),ci,'ko','markerfacecolor',ones(1,3)*0.8,...
        'markersize',8,'linewidth',1,'CapSize',0);
    set(gca,'color','none','box','off','FontSize',fs,'tickdir','out')
    set(gca,'ytick',0.5:0.2:1,'xtick',seqLength,'linewidth',1,'fontsize',fs)
    xlim([7,21])
    
    ylim([ybtm,ytop])
    xlabel('sequence length')
    if icond==1
        legend(h,{'leak + noise (full)','human'},'box','off','location','s')
    end

    if icond==1
        ylabel('match accuracy')
    end
    if icond==2
        ylabel('guess accuracy')
    end

    ax = nexttile;
    
    cfg           = [];
    cfg.plotline  = 1;
    cfg.linewidth = 2;
    cfg.plotdots  = 1;
    cfg.alpha     = alpha;

    cfg_human = cfg;
    cfg_human.plotline = 0;
    cfg.doSE = 1;
    
    ci = 1;
    deviation = acc_model(:,:,[1,3,2,4]);

    Mean_d = squeeze(mean(deviation,2,'omitnan'));

    ci_human = std(mean(acc_human,2))./sqrt(nsubj)*1.96;
    mean_human = mean(mean(acc_human,2));

    for k = 1:4
        c = col(k,:);
        b = bar(k,mean(Mean_d(:,k)),...
            'FaceColor',c,'EdgeColor',c,'linewidth',1.5);
        b.FaceAlpha = t(k);
        b.EdgeAlpha = t(k)*2;

        hold on;
        ci = std(Mean_d(:,k))./sqrt(nsubj)*1.96;
        errorbar(k, mean(Mean_d(:,k)),ci,...
             'color', c, 'linewidth', 1.5, 'CapSize', 0);
        % data distribution:
        jitter_scatter(Mean_d(:,k), k, c, 0);

        KOname = {'KO leak & noise','KO leak','KO noise','full'};
        text(k, ybtm+0.02, KOname{k}, ...
         'HorizontalAlignment', 'left', 'Rotation', 90, ...
         'VerticalAlignment', 'middle',...
         'Color',c, 'FontSize', 16);
       
        hold on;

    end

    human_x = 5;
    jitter_scatter(mean(acc_human,2), human_x, ones(1,3)*0.4);
    errorbar(human_x,mean_human,ci_human,'ko','markerfacecolor',ones(1,3)*0.8,...
        'markersize',8,'linewidth',1,'CapSize',0);

    set(gca,'color','none','box','off','FontSize',fs,'tickdir','out')
    set(gca,'ytick',0.5:0.2:1,'xtick','','linewidth',1,'fontsize',fs)
    off = 0.5;
    xlim([1-off,human_x+0.35])
    
    ylim([ybtm,ytop])
    xlabel('knockout type')
    h = xlabel('knockout type');
    pos = get(h, 'Position');  
    pos(1) = pos(1) - 0.8;        
    pos(2) = pos(2) - 0.02;
    set(h, 'Position', pos);

    if icond==1
        ylabel('mean match accuracy')
    else
        ylabel('mean guess accuracy')
    end
    
    if icond==1
        tt = title(ax, '{\it{Ex post}} model simulation');
        tt.FontWeight = 'normal';  % remove bold
            pos = tt.Position;
        pos(1) = pos(1) - 3.8; % adjust this value as needed
        pos(2) = pos(2) + 0.02;
        tt.Position = pos;
    end
    
end
set(gcf, 'Renderer', 'painters'); % 
set(gcf, 'PaperPositionMode', 'auto');