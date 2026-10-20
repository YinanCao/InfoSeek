clear;clc;close all;

dataset = 'COLINE';
% load human data;
load(['dat_choicestbl_',dataset,'.mat'],'choicestbl');
choicestbl(choicestbl.excludepart == true,:) = [];
data = choicestbl;
unique_ids = unique(data.subj);
nsubj = length(unique_ids);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
nsmpMax      = 20;
seqLength    = [8,12,16,20];
cfac         = 1.4386;
pSW_byval    = cell(nsubj,2); % p(repeat) per participant and condition, stored with its evidence value

for s = nsubj:-1:1
    subj_id = unique_ids(s);
    for cond = 1:2 % match=1, guess=2
        
        % get raw data
        subj_num = subj_id;
        iseq    = find(data.subj == subj_num & data.condition == cond);
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
        colvals(isbad) = [];
        choices(isbad) = [];
        nsample(isbad) = [];
        guesspc(isbad) = [];
        colorop(isbad) = [];

        % create configuration structure
        cfg = [];
        cfg.targetc = targetc_cfg; % for simulation!
        cfg.colvals = colvals;
        cfg.colorop = colorop; % for simulation!
        cfg.choices = choices;
        cfg.same1st = false;
        seql = cellfun(@(x)size(x,2),cfg.choices);
        nseq = length(cfg.choices);

        if cond == 1
            for k = 1:4
                ch_cf = cfg.choices(ctfactn==3 & nsample==seqLength(k));
                matrix_ch_cf = cell2mat(ch_cf);
                acc = double(matrix_ch_cf==1);
                acc(isnan(matrix_ch_cf)) = nan;
                pc_match{k}(s,:) = mean(acc,1,'omitnan');
            end
        end

        % human:
        mvopt = cell(0); mcopt = cell(0);
        psw = [];
        for iseq = 1:nseq
            c  = cfg.colvals{iseq}';
            c  = c*cfac;
            xc = zeros(size(c,1),2);
            xc(2:end,:) = cumsum(c(1:end-1,:),1,'omitnan');
            
            [~, tempopt]  = max(xc*cfg.targetc(iseq),[],2);
            mvopt{iseq,1} = [cfg.choices{iseq}==tempopt' nan(1,20-size(cfg.choices{iseq},2))];
            mvopt{iseq,1}(xc(:,1)==xc(:,2)) = nan; % if options are equal, nan

            [~, tempopt] = min(abs(xc),[],2);
            mcopt{iseq,1}  = [cfg.choices{iseq}==tempopt' nan(1,20-size(cfg.choices{iseq},2))];
            mcopt{iseq,1}(abs(xc(:,1))==abs(xc(:,2))) = nan; % if options are equal, nan

            prior = xc;
            ch = cfg.choices{iseq};
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

        % bin:
        rmv = psw(:,1)==0 | isnan(psw(:,2));
        psw(rmv, :) = [];
        psw = round(psw, 5);
        evi_level = unique(psw(:,1));

        % for lev_i = 1:length(evi_level)
        %     pSW(s,lev_i,cond) = 1-mean(psw(psw(:,1)==evi_level(lev_i), 2));
        % end
        % store p(repeat) with its evidence value; columns are aligned by value after the subject loop
        pSW_byval{s,cond} = [evi_level, arrayfun(@(v) 1-mean(psw(psw(:,1)==v,2)), evi_level)];

        % unused 8-bin version of p(repeat) (not plotted or reported)
        % n_bins = 8;  % or set as desired
        % % define bin edges
        % edges = linspace(-cfac, +cfac, n_bins+1);
        % bin_centers = edges(1:end-1) + diff(edges)/2;
        % % assign each trial to a bin
        % bin_idx = discretize(psw(:,1), edges);
        % for lev_i = 1:n_bins
        %     this_bin = bin_idx == lev_i;
        %     if any(this_bin)
        %         pSW_set(s,lev_i,cond) = 1 - mean(psw(this_bin,2));
        %     else
        %         pSW_set(s,lev_i,cond) = NaN;  % optional: NaN if no trials in bin
        %     end
        % end

        dir_c(s,:,cond,1) = mean(cell2mat(mcopt),1,'omitnan');
        dir_v(s,:,cond,1) = mean(cell2mat(mvopt),1,'omitnan');

        %%%%%%%%%%%%%%%%%%%%%%%%
        % fraction repeat (human)
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
            spstay_human(s,idx,cond,1) = mean(srepeat(ich),'omitnan');
        end

        if cond==2 % guess task
            guessPc_human(s,:) = arrayfun(@(l)mean(guesspc(seql==l)),seqLength);
        end

        sp = nan(nseq,20); % single-trial chunking
        for iseq = 1:nseq
            for idx = 1:max(max(sprevch))
                ich = find(sprevch(iseq,:)==idx);
                sp(iseq,idx) = mean(srepeat(iseq, ich),'omitnan');
                % spstay_human(s,idx,cond,1) = nanmean(srepeat(ich));
            end
        end

        % choice to choice similarity:
        similarity_matrices = [];
        for iseq = 1:nseq
            ch = cfg.choices{iseq};
            T = numel(ch);
            sim_mat = nan(20, 20);
            for i = 1:T
                for j = 1:T
                    sim_mat(i, j) = double(ch(i) == ch(j));
                end
            end
            similarity_matrices(:,:,iseq) = sim_mat;
        end
        ch2chM(s,:,:,cond) = mean(similarity_matrices,3,'omitnan');

    end % cond
end % sub

% align p(repeat) across participants by evidence value, not by position:
% fix the reference levels once, pre-fill with NaN, place each value in its matching column
lev_all   = cellfun(@(x) x(:,1), pSW_byval(:), 'UniformOutput', false);
evi_level = unique(vertcat(lev_all{:}));
pSW       = nan(nsubj, numel(evi_level), 2);
for isub = 1:nsubj
    for icnd = 1:2
        [~, lev_loc] = ismember(pSW_byval{isub,icnd}(:,1), evi_level);
        pSW(isub,lev_loc,icnd) = pSW_byval{isub,icnd}(:,2)';
    end
end
fprintf('Signed-evidence levels: %d\n', numel(evi_level));

disp('done')

close all; clc
configALL;

% stats for match:
clc
x = [8, 12, 16, 20];

pc = [];
for k = 4:-1:1
    pc(:,k) = pc_match{k}(:,end);
end
nSub = size(pc,1);
% Per-subject linear slope across sequence lengths
slope = zeros(nSub,1);
for i = 1:nSub
    coeffs   = polyfit(x, pc(i,:), 1);
    slope(i) = coeffs(1);
end
% Test 1: last-trial accuracy against chance (0.5)
report_ttest(mean(pc,2), 0.5, 'Accuracy vs. chance, match');
% Test 2: linear trend, slope against 0
report_ttest(slope, 0, 'Linear trend (slope per choice), match');

% stats for guess:
pc = guessPc_human;
nSub = size(pc,1);
% Per-subject linear slope across sequence lengths
slope = zeros(nSub,1);
for i = 1:nSub
    coeffs   = polyfit(x, pc(i,:), 1);
    slope(i) = coeffs(1);
end
% Test 1: last-trial accuracy against chance (0.5)
report_ttest(mean(pc,2), 0.5, 'Accuracy vs. chance, guess');
% Test 2: linear trend, slope against 0
report_ttest(slope, 0, 'Linear trend (slope per choice), guess');


col = lines;
col(1,:) = col(4,:);
col(2,:) = col(5,:);

c = lines;
guess         = c(5,:); % human
cfg           = [];
cfg.plotline  = 1;
cfg.linewidth = 1;
cfg.plotdots  = 0;
cfg.alpha     = alpha/1.8;
cfg.dotsize   = 1;

figure('position',[420   274   958   464])

subplot(2,4,1)
for k = 1:4
    plotpatch(pc_match{k}(:,2:end),2:seqLength(k),c(4,:),cfg); hold on
end
for k = 1:4
    y = pc_match{k}(:,end);
    se = std(y)./sqrt(nsubj) * 1.96;
    errorbar(seqLength(k),mean(y),se,'ko','markerfacecolor',c(4,:),...
        'markersize',ms,'linewidth',1,'CapSize',0);
end
set(gca,'color','none','box','off','FontSize',fs,'tickdir','out')
set(gca,'ytick',[0,0.5,0.85],'xtick',seqLength,'linewidth',1,'fontsize',fs)
ylim([0.45,0.85])
xlabel('choice position')
ylabel('match accuracy')
xlim([0,20])
plot([1,20],[0.5,0.5],'k--','linewidth',1)
xl = xlim;
midp = mean(xl);
text(midp,0.85,'match','color',col(1,:),'FontSize',fs,'HorizontalAlignment', 'center')


subplot(2,4,2)
h = [];
cfg_human = cfg;
cfg_human.plotline = 0;
se = std(guessPc_human)./sqrt(nsubj)*1.96;
h(4) = errorbar(seqLength,mean(guessPc_human),se,'ko','markerfacecolor',guess,...
    'markersize',ms,'linewidth',1,'CapSize',0); hold on
plot([1,20],[0.5,0.5],'k--','linewidth',1)
set(gca,'color','none','box','off','FontSize',fs,'tickdir','out')
set(gca,'ytick',[0.5,0.85],'xtick',seqLength,'linewidth',1,'fontsize',fs)
xlim([0,20])
ylim([0.45,0.85])
xlabel('sequence length')
ylabel('guess accuracy')
xl = xlim;
midp = mean(xl);
text(midp,0.85,'guess','color',col(2,:),'FontSize',fs,'HorizontalAlignment', 'center')



ll = [20, 20];
tmp = {dir_v, dir_c};
ylimrange = {[0,1],[0,1]};
cc = {1,[1,2]};
pol_name = {'Target-guided','Uncertainty-guided'}; % console labels
cnd_name = {'match','guess'};
sd = 1.96;
for panel = 1:2
    liim = ll(panel);
    spstay = tmp{panel};
    ax=subplot(2,4,panel+2);
    Dcontr = [];
    for icond = cc{panel}
        hold on
        x_ax     = 2:liim;
        D        = spstay(:,x_ax,icond);
        X_patch  = [x_ax, fliplr(x_ax)];
        yup      = mean(D,'omitnan') + ( std(D,'omitnan') / sqrt(nsubj)*sd ) ;
        ylo      = mean(D,'omitnan') - ( std(D,'omitnan') / sqrt(nsubj)*sd ) ;
        Y_patch  = [yup,flip(ylo)];
        fill(X_patch, Y_patch , 1, 'facecolor', 0.5*(col(icond,:)+1), 'edgecolor','none', 'facealpha', alpha*2);
        plot(x_ax, mean(spstay(:,x_ax,icond),'omitnan'), '-', 'Color', col(icond,:), 'LineWidth', 1.5);           

        [~, p, ~, st] = ttest(D, 0.5, 'Tail', 'right');
        p = squeeze(p);
        Tpeak = max(st.tstat);
        % report_ttest_peak(D, 0.5, 'right', 'Target-like policy alignment');
        % report_ttest_peak(D, 0.5, 'right', sprintf('%s policy alignment vs. 0.5, %s', pol_name{panel}, cnd_name{icond}));
        report_ttest_peak(D, 0.5, 'right', sprintf('%s policy alignment vs. 0.5, %s', pol_name{panel}, cnd_name{icond}), x_ax);   % x_ax = trial numbers of D's columns

        qvals = x_ax(mafdr(p, 'BHFDR', true)<0.005);
        draw_sig(qvals, 0.9, siglw, condcolor{icond})
        % plot(qvals,qvals*0+0.9,'-','linewidth',siglw,'color',condcolor{icond})
        text(2,0.96,'one-sided t-test against 0.5','Color',condcolor{icond})

        if panel==2
            Dcontr(:,:,icond) = D;
        end

    end
    xlabel('sampling trial')
    ylabel('p(policy-guided choice)');
    title_name = {'target guided','uncertainty guided'};
    t = title(ax, title_name{icond}); 
    t.FontWeight = 'normal';  % remove bold
    t.Color = ones(1,3)*0.5;

    set(gca,'xtick',[2,seqLength],'xticklabelrotation',0,'ytick',[0.0,0.5,1])

    set(gca,'color','none','linewidth',1,'tickdir','out','fontsize',fs)
    ylim(ylimrange{panel})
    xlim([0.5,inf])
    plot([0,20],[0.5,0.5],'k--','LineWidth',1)
    if panel==1
        text(16,0.8,'match','color',col(1,:),'FontSize',fs/1.2)
    end

    if panel==2 % uncertainty-guided
        Dcontr = Dcontr(:,:,2)-Dcontr(:,:,1);
        [~, p,~,st] = ttest(Dcontr, 0, 'Tail', 'both');
        p = squeeze(p);
        % report_ttest_peak(Dcontr, 0, 'both', 'Uncertainty-guided policy alignment');
        % report_ttest_peak(mean(Dcontr,2), 0, 'both', 'uncertain mean');
        % report_ttest_peak(Dcontr, 0, 'both', 'Uncertainty-guided policy alignment, guess minus match');
        report_ttest_peak(Dcontr, 0, 'both', 'Uncertainty-guided policy alignment, guess minus match', x_ax);
        report_ttest_peak(mean(Dcontr,2), 0, 'both', 'Uncertainty-guided policy alignment, guess minus match, mean over trials');

        qvals = x_ax(mafdr(p, 'BHFDR', true)<0.005);
        draw_sig(qvals, 0.85, siglw, chancecolor)
        text(2,0.8,'two-sided contrast','Color',chancecolor)
    end

end
text(16,0.6,'guess','color',col(2,:),'FontSize',fs/1.2)
text(16,0.4,'match','color',col(1,:),'FontSize',fs/1.2)


subplot(2,4,5)
ylimrange = [0.5,1];
sd = 1.96;
liim = 10;
x_ax     = 1:liim;
data = spstay_human(:,x_ax,:);
delta = data(:,:,2)-data(:,:,1);
[~,p,ci,st] = ttest(delta);
p = squeeze(p);
qvals = x_ax(mafdr(p, 'BHFDR', true)<0.005);
Tpeak_c_rep = max(st.tstat);
% report_ttest_peak(mean(delta(:,1:2),2), 0, 'both', '');
report_ttest_peak(mean(delta(:,1:2),2), 0, 'both', 'p(repeat next), guess minus match, mean of first 2 points');


for icond = 1:2
    hold on
    X_patch  = [x_ax, fliplr(x_ax)];
    D = data(:,:,icond);
    yup      = mean(D,'omitnan') + ( std(D,'omitnan') / sqrt(nsubj)*sd );
    ylo      = mean(D,'omitnan') - ( std(D,'omitnan') / sqrt(nsubj)*sd );
    Y_patch  = [yup,flip(ylo)];
    fill(X_patch, Y_patch , 1, 'facecolor', 0.5*(col(icond,:)+1), 'edgecolor','none', 'facealpha', alpha*2); % patch ErrBar
    plot(x_ax, mean(data(:,x_ax,icond),'omitnan'), '-', 'Color', col(icond,:), 'LineWidth', 1.5); % plot mean line
end
draw_sig(qvals, 0.95, siglw, chancecolor)
text(1,0.98,'two-sided contrast','Color',chancecolor)
xlabel('times seen before')
ylabel(sprintf('p(repeat next)'));
set(gca,'xtick',[1,4,7,10],'ytick',0.5:0.25:1)
set(gca,'color','none','linewidth',1,'tickdir','out','fontsize',fs)
ylim(ylimrange)
xlim([0.5,liim])
text(8,0.64,'guess','color',col(2,:),'FontSize',fs/1.2)
text(8,0.84,'match','color',col(1,:),'FontSize',fs/1.2)


subplot(2,4,6)
ylimrange = [0.5,1];
sd = 1.96;
liim = length(evi_level);
data = pSW;
delta = data(:,:,1)-data(:,:,2);
[~,p] = ttest(delta);
p = squeeze(p);
% qvals = x_ax(mafdr(p, 'BHFDR', true)<0.005);  (original)
qvals = find(mafdr(p, 'BHFDR', true) < 0.005);   % indices of significant evidence levels
for icond = 1:2
    hold on
    x_ax     = evi_level';
    X_patch  = [x_ax, fliplr(x_ax)];
    D = data(:,:,icond);
    yup = mean(D,'omitnan') + ( std(D,'omitnan') / sqrt(nsubj)*sd );
    ylo = mean(D,'omitnan') - ( std(D,'omitnan') / sqrt(nsubj)*sd );
    Y_patch  = [yup,flip(ylo)];
    fill(X_patch, Y_patch, 1, 'facecolor', 0.5*(col(icond,:)+1), 'edgecolor','none', 'facealpha', alpha*2); % patch ErrBar
    plot(x_ax, mean(data(:,:,icond),'omitnan'), '-', 'Color', col(icond,:), 'LineWidth', 1.5); % plot mean line
end
xlabel('signed evidence (logLR)')
ylabel(sprintf('p(repeat next)'));
xtick = round(evi_level([1,3,6,liim]),1);
hold on;
plot([0,0],[0,0.94],'k--','linewidth',1)
% xtick = [xtick(1), 0, xtick(2)]
set(gca,'xtick',xtick,'ytick',0.5:0.25:1,'xticklabel',xtick)
set(gca,'color','none','linewidth',1,'tickdir','out','fontsize',fs)
ylim(ylimrange)
of = 0.02;
xlim([-1.48-of,1.48+of])
text(0.8,0.63,'guess','color',col(2,:),'FontSize',fs/1.2)
text(0.8,0.88,'match','color',col(1,:),'FontSize',fs/1.2)
draw_sig(evi_level(qvals), 0.95, siglw, chancecolor)
% plot(evi_level(qvals),qvals*0+0.95,'-','linewidth',siglw,'color',chancecolor)
text(-1.4,0.98,'two-sided contrast','Color',chancecolor)



ax = [];
for condi = 1:2
    ax(condi+1) = subplot(2,4,condi+6);  % positions 3 and 4 in a 2×2 grid
    % Extract data
    x = squeeze(ch2chM(:,:,:,condi));
    mean_map = squeeze(mean(x, 1));
    mask = triu(true(size(mean_map)), 1);
    mean_map(mask) = NaN;

    im = imagesc(tril(mean_map, -1));  % strictly lower triangle, no diagonal
    dumb = tril(ones(20,20), -1);      % alpha mask excluding the diagonal
    set(im, 'AlphaData', dumb);
    set(ax(condi+1), 'YDir', 'normal');

    clim(ax(condi+1), [0.3 0.7]);

    set(ax(condi+1), 'color','none','box','off','tickdir','out','xtick',[1,5:5:20],'ytick',[2,5:5:20]);
    xlabel(ax(condi+1), 'choice in sequence','fontsize',fs);
    ylabel(ax(condi+1), 'choice in sequence','fontsize',fs);
    grid(ax(condi+1), 'off');
    set(ax(condi+1),'fontsize',fs,'linewidth',1)

    if condi == 1
        colormap(ax(condi+1), magma);
    else
        colormap(ax(condi+1), viridis);
    end

    cb = colorbar(ax(condi+1));
    cb.FontSize = fs/1.5;
    % make it narrower
    pos = cb.Position;
    pos(4) = pos(4) * 0.3;  % reduce height to 50%
    % optionally shift upward to keep it centered
    pos(2) = pos(2) + pos(4)/2;
    cb.Position = pos;
    cb.Ticks = [0.3 0.7];
    cb.LineWidth = 0.01;
    text(14.5, 2.5, 'similarity', 'Rotation', 90);

    title_name = {'match','guess'};
    t = title(ax(condi+1), title_name{condi}); 
    t.FontWeight = 'normal';  % remove bold
    t.Color = col(condi,:);

    axis square
end

set(gcf, 'Renderer', 'painters'); %
set(gcf, 'PaperPositionMode', 'auto');