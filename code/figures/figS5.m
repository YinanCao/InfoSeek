clear; clc; close all;

dataset = 'COLINE';
% Load human data
load(['dat_choicestbl_',dataset,'.mat'],'choicestbl');
choicestbl(choicestbl.excludepart == true,:) = [];

data = choicestbl;
unique_ids = unique(data.subj);
nsubj = numel(unique_ids);

load dat_modelparELBO_COLINE.mat

% General settings
nsmpMax = 20;
seqLength = [8,12,16,20];
cfac = 1.4386;
nSim = 10;   % fast default; the published Supplementary Fig. 5 used nSim = 1000

variant_name = {'full model','\theta = 0','\beta_v = 0','\beta_r = 0','\beta_c = 0','no leak','no inference noise'};
nVariant = numel(variant_name);

% Preallocate outputs

parameter = nan(nsubj,8,2);
elbo = nan(nsubj,2);

spstay_human = nan(nsubj,nsmpMax,2);
spstay_model = nan(nsubj,nsmpMax,2,nVariant,nSim);

dir_v_human = nan(nsubj,nsmpMax,2);
dir_c_human = nan(nsubj,nsmpMax,2);

dir_v_model = nan(nsubj,nsmpMax,2,nVariant,nSim);
dir_c_model = nan(nsubj,nsmpMax,2,nVariant,nSim);

pSW_human = [];
pSW_model = [];

% Loop over subjects

for s = nsubj:-1:1

    subj_id = unique_ids(s);
    disp(['simulating subject #',num2str(s)])

    for cond = 1:2

        % Extract fitted parameters
        irow = modelfit.subj == subj_id & ...
            modelfit.("model(1=exact,2=leak,3=noise,4=leaknoise,5=leaknoiseNOthr)") == 4 & ...
            modelfit.("condition(1=bandit,2=guess)") == cond;

        out = modelfit(irow,:);

        if height(out) ~= 1
            error('Expected one fitted parameter row for subject %d, condition %d, but found %d.',subj_id,cond,height(out))
        end

        % Extract behavioral data
        row_idx = find(data.subj == subj_id & data.condition == cond);

        conditn = data.condition(row_idx);
        ctfactn = data.symmetry(row_idx);
        targetc = 2*data.targetcolor(row_idx)-3;
        targetc_cfg = (2*data.targetcolor(row_idx)-3).*(conditn ~= 2);
        colvals = data.colorseen(row_idx);
        choices = data.choices(row_idx);
        nsample = data.nsamples(row_idx);
        guesspc = data.finalchoicecorr(row_idx);
        colorop = data.coloroptions(row_idx);

        for iseq = 1:numel(choices)
            colvals{iseq} = colvals{iseq}(:,1:nsample(iseq));
            choices{iseq} = choices{iseq}(1:nsample(iseq));
            colorop{iseq} = colorop{iseq}(:,1:nsample(iseq));
        end

        % Remove sequences containing missing choices

        isbad = cellfun(@(x)any(isnan(x)),choices);

        conditn(isbad) = [];
        ctfactn(isbad) = [];
        targetc(isbad) = [];
        targetc_cfg(isbad) = [];
        colvals(isbad) = [];
        choices(isbad) = [];
        nsample(isbad) = [];
        guesspc(isbad) = [];
        colorop(isbad) = [];

        % Configuration structure

        cfg = [];
        cfg.conditn = cond;
        cfg.targetc = targetc_cfg;
        cfg.colvals = colvals;
        cfg.colorop = colorop;
        cfg.choices = choices;
        cfg.same1st = false;
        cfg.shuffle = false;
        cfg.cfac = cfac;

        nseq = numel(cfg.choices);

        % Best-fitting parameters

        base.betav = out.betav;
        base.betac = out.betac;
        base.betar = out.betar;
        base.theta = out.theta;
        base.epsilon = out.epsilon;
        base.gamma = out.gamma;
        base.delta_c = out.deltac;
        base.delta_u = out.deltau;
        base.sigma = out.sigma;

        parameter(s,:,cond) = [base.delta_c,base.delta_u,base.sigma,base.betav,base.betac,base.betar,base.theta,base.epsilon];
        elbo(s,cond) = out.elbo;

        % Simulate full model and parameter knockouts

        for ivariant = 1:nVariant

            pars = base;

            switch ivariant
                case 1
                    % Full model
                case 2
                    pars.theta = 0;
                case 3
                    pars.betav = 0;
                case 4
                    pars.betar = 0;
                case 5
                    pars.betac = 0;
                case 6
                    pars.delta_c = 0;
                    pars.delta_u = 0;
                case 7
                    pars.sigma = 0;
            end

            for isim = 1:nSim

                [mch,~,mfq] = sim_modelbound_noisyleaky(pars.betav,pars.betac,pars.betar,pars.theta,pars.epsilon,pars.gamma,pars.delta_c,pars.delta_u,pars.sigma,cfg);

                % Fraction repeated as a function of previous sampling count

                sprevch = nan(nseq,nsmpMax);
                srepeat = nan(nseq,nsmpMax);

                for iseq = 1:nseq
                    ch = mch{iseq};
                    nsmp = numel(ch);

                    for ismp = 1:nsmp-1
                        sprevch(iseq,ismp) = sum(ch(1:ismp) == ch(ismp));
                        srepeat(iseq,ismp) = ch(ismp) == ch(ismp+1);
                    end
                end

                max_seen = max(sprevch(:),[],'omitnan');

                for idx = 1:max_seen
                    ich = sprevch == idx;
                    spstay_model(s,idx,cond,ivariant,isim) = mean(srepeat(ich),'omitnan');
                end

                % Policy-guided choices and evidence-dependent repetition

                mvopt = cell(nseq,1);
                mcopt = cell(nseq,1);
                psw = [];

                for iseq = 1:nseq

                    ch = mch{iseq};
                    c = cfg.colorop{iseq}';
                    ntrl = numel(ch);

                    for trl = 1:ntrl
                        c(trl,3-ch(trl)) = nan;
                    end

                    c = c*cfac;
                    xc = zeros(size(c,1),2);
                    xc(2:end,:) = cumsum(c(1:end-1,:),1,'omitnan');

                    [~,tempopt] = max(xc*cfg.targetc(iseq),[],2);
                    mvopt{iseq} = [ch == tempopt',nan(1,nsmpMax-numel(ch))];
                    mvopt{iseq}(xc(:,1) == xc(:,2)) = nan;

                    [~,tempopt] = min(abs(xc),[],2);
                    mcopt{iseq} = [ch == tempopt',nan(1,nsmpMax-numel(ch))];
                    mcopt{iseq}(abs(xc(:,1)) == abs(xc(:,2))) = nan;

                    prior = xc;
                    chosen_prior = nan(size(prior,1),1);

                    for trl = 1:size(prior,1)
                        chosen_prior(trl) = prior(trl,ch(trl));
                    end

                    chosen_evi = sum(c,2,'omitnan');
                    belief_aligned_evi = chosen_evi.*sign(chosen_prior);
                    target_aligned_evi = cfg.targetc(iseq)*chosen_evi;
                    repeat_next = [ch(2:end) == ch(1:end-1),nan]';

                    if cond == 1
                        signed_evi = target_aligned_evi;
                    else
                        signed_evi = belief_aligned_evi;
                    end

                    psw = [psw;signed_evi,repeat_next];
                end

                dir_c_model(s,:,cond,ivariant,isim) = mean(cell2mat(mcopt),1,'omitnan');
                dir_v_model(s,:,cond,ivariant,isim) = mean(cell2mat(mvopt),1,'omitnan');

                psw(psw(:,1) == 0 | isnan(psw(:,2)),:) = [];
                psw(:,1) = round(psw(:,1),5);
                evi_level_sim = unique(psw(:,1));

                for lev_i = 1:numel(evi_level_sim)
                    pSW_model(s,lev_i,cond,ivariant,isim) = mean(psw(psw(:,1) == evi_level_sim(lev_i),2),'omitnan');
                end

            end
        end

        % Human repetition as a function of previous sampling count

        sprevch = nan(nseq,nsmpMax);
        srepeat = nan(nseq,nsmpMax);

        for iseq = 1:nseq
            ch = cfg.choices{iseq};
            nsmp = numel(ch);

            for ismp = 1:nsmp-1
                sprevch(iseq,ismp) = sum(ch(1:ismp) == ch(ismp));
                srepeat(iseq,ismp) = ch(ismp) == ch(ismp+1);
            end
        end

        max_seen = max(sprevch(:),[],'omitnan');

        for idx = 1:max_seen
            ich = sprevch == idx;
            spstay_human(s,idx,cond) = mean(srepeat(ich),'omitnan');
        end

        % Human policy-guided choices and evidence-dependent repetition

        mvopt = cell(nseq,1);
        mcopt = cell(nseq,1);
        psw = [];

        for iseq = 1:nseq

            ch = cfg.choices{iseq};
            c = cfg.colvals{iseq}'*cfac;

            xc = zeros(size(c,1),2);
            xc(2:end,:) = cumsum(c(1:end-1,:),1,'omitnan');

            [~,tempopt] = max(xc*cfg.targetc(iseq),[],2);
            mvopt{iseq} = [ch == tempopt',nan(1,nsmpMax-numel(ch))];
            mvopt{iseq}(xc(:,1) == xc(:,2)) = nan;

            [~,tempopt] = min(abs(xc),[],2);
            mcopt{iseq} = [ch == tempopt',nan(1,nsmpMax-numel(ch))];
            mcopt{iseq}(abs(xc(:,1)) == abs(xc(:,2))) = nan;

            prior = xc;
            chosen_prior = nan(size(prior,1),1);

            for trl = 1:size(prior,1)
                chosen_prior(trl) = prior(trl,ch(trl));
            end

            chosen_evi = sum(c,2,'omitnan');
            belief_aligned_evi = chosen_evi.*sign(chosen_prior);
            target_aligned_evi = cfg.targetc(iseq)*chosen_evi;
            repeat_next = [ch(2:end) == ch(1:end-1),nan]';

            if cond == 1
                signed_evi = target_aligned_evi;
            else
                signed_evi = belief_aligned_evi;
            end

            psw = [psw;signed_evi,repeat_next];
        end

        dir_c_human(s,:,cond) = mean(cell2mat(mcopt),1,'omitnan');
        dir_v_human(s,:,cond) = mean(cell2mat(mvopt),1,'omitnan');

        psw(psw(:,1) == 0 | isnan(psw(:,2)),:) = [];
        psw(:,1) = round(psw(:,1),5);
        evi_level = unique(psw(:,1));

        for lev_i = 1:numel(evi_level)
            pSW_human(s,lev_i,cond) = mean(psw(psw(:,1) == evi_level(lev_i),2),'omitnan');
        end

    end
end

% Plot settings
%%
clc; close all;
configALL;

patchcolor = [condcolor{1};condcolor{2}];

plot_cfg = [];
plot_cfg.plotdots = false;
plot_cfg.plotline = true;
plot_cfg.shading = true;
plot_cfg.linewidth = 1.5;
plot_cfg.alpha = alpha;

human_data = {dir_v_human(:,2:end,1),dir_c_human(:,2:end,:),spstay_human(:,1:10,:),pSW_human};
xvalue = {2:20,2:20,1:10,evi_level'};
yrange = {[0,1],[0,1],[0.5,1],[0.5,1]};
xlabnames = {'sampling trial','sampling trial','times seen before','signed evidence (logLR)'};
ylabnames = {'p(policy-guided choice)','p(policy-guided choice)','p(repeat next)','p(repeat next)'};
column_title = {'target guided','uncertainty guided','',''};

% Plot all knockouts

for ivariant = 1:nVariant

    figure('position',[420   274   800   200],'name',variant_name{ivariant})
    tiledlayout(1, 4, 'TileSpacing', 'compact', 'Padding', 'compact'); % 2x2 grid

    model_data = {
        squeeze(mean(dir_v_model(:,2:end,1,ivariant,:),5,'omitnan')), ...
        squeeze(mean(dir_c_model(:,2:end,:,ivariant,:),5,'omitnan')), ...
        squeeze(mean(spstay_model(:,1:10,:,ivariant,:),5,'omitnan')), ...
        squeeze(mean(pSW_model(:,:,:,ivariant,:),5,'omitnan'))};

    for i = 1:4

        nexttile;
        hold on;

        m = squeeze(mean(human_data{i},1,'omitnan'));
        se = squeeze(std(human_data{i},0,1,'omitnan')/sqrt(nsubj)*1.96);

        if size(m,1) < 2
            m = m';
            se = se';
        end

        h_human = gobjects(1,1);

        for k = 1:size(m,2)
            htmp = errorbar(xvalue{i},m(:,k),se(:,k),'o','MarkerFaceColor',ones(1,3)*0.8,'MarkerSize',5,'LineWidth',1,'CapSize',0,'Color',patchcolor(k,:));
            if k == 1
                h_human = htmp;
            end
        end

        h_model = plotpatch(model_data{i},xvalue{i},patchcolor,plot_cfg);

        if i == 1 || i == 2
            plot([0,20],[0.5,0.5],'k--','LineWidth',1);
            xlim([1,20]);
            set(gca,'XTick',[2,8,12,16,20],'YTick',0:0.5:1);
        elseif i == 3
            xlim([0.5,10]);
            set(gca,'XTick',[1,4,7,10],'YTick',0.5:0.25:1);
        elseif i == 4
            plot([0,0],[0.5,1],'k--','LineWidth',1);
            xlim([min(evi_level)-0.02,max(evi_level)+0.02]);
            tick_idx = unique(round(linspace(1,numel(evi_level),4)));
            set(gca,'XTick',round(evi_level(tick_idx),1),'YTick',0.5:0.25:1);
        end

        xlabel(xlabnames{i});
        ylabel(ylabnames{i});
        ylim(yrange{i});

        set(gca,'Color','none','LineWidth',1,'TickDir','out','FontSize',fs,'Box','off','XTickLabelRotation',0);

        fs_t = fs/1.2;

        if ivariant == 1
            if i == 1
                text(17,0.8,'match','Color',match,'FontSize',fs_t,'HorizontalAlignment','center');
            elseif i == 2
                text(17,0.26,'match','Color',match,'FontSize',fs_t,'HorizontalAlignment','center');
                text(17,0.66,'guess','Color',guess,'FontSize',fs_t,'HorizontalAlignment','center');
            elseif i == 3
                text(9,0.85,'match','Color',match,'FontSize',fs_t,'HorizontalAlignment','center');
                text(9,0.63,'guess','Color',guess,'FontSize',fs_t,'HorizontalAlignment','center');
            elseif i == 4
                text(max(evi_level)*0.7,0.9,'match','Color',match,'FontSize',fs_t,'HorizontalAlignment','center');
                text(max(evi_level)*0.7,0.6,'guess','Color',guess,'FontSize',fs_t,'HorizontalAlignment','center');
            end
        end

        if ivariant == 1 && ~isempty(column_title{i})
            t = title(column_title{i});
            t.FontWeight = 'normal';
            t.Color = ones(1,3)*0.5;
        end

        if ivariant == 1 && i == 1
            legend([h_human,h_model(1)],{'human','model'},'Location','southwest','Color','none','Box','off');
        end

    end
end

set(gcf,'Renderer','painters');
set(gcf,'PaperPositionMode','auto');