clear; clc; close all;
rng(1234);
load('dat_choicestbl_COLcued.mat');

% load human data;
choicestbl(choicestbl.excludepart == true,:) = [];
data = choicestbl;
unique_ids = unique(data.subj);
nsubj = numel(unique_ids);

color_scale = linspace(-1,1,8);
nsmpMax = 20;
cfac = 1.4386;
sd = 1.96;
acc_thres = 0.6;
choicetype_list = [0,1,2];
length_list = [8,12,16,20];
condLabels = {'free','cued (S)','cued (NS)'};
guess_acc = nan(nsubj,numel(choicetype_list),5);

% Extract behavioral data
for s = nsubj:-1:1

    subj_id = unique_ids(s);
    disp(['simulating subject #',num2str(s)])

    Age(s,1) = mean(data.Age(data.subj == subj_id));
    Sex(s,1) = mean(data.Sex(data.subj == subj_id)=='Female');

    for ct = 1:length(choicetype_list)

        choiceType = choicetype_list(ct);
        row_idx = find(data.subj == subj_id & data.choiceType == choiceType);
        conditn = data.condition(row_idx);
        % ctfactn = data.symmetry(row_idx);
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
        targetc(isbad) = [];
        targetc_cfg(isbad) = [];
        colvals(isbad) = [];
        choices(isbad) = [];
        nsample(isbad) = [];
        guesspc(isbad) = [];
        colorop(isbad) = [];

        nseq = numel(choices);

        % Human repetition as a function of previous sampling count
        sprevch = nan(nseq,nsmpMax);
        srepeat = nan(nseq,nsmpMax);

        for iseq = 1:nseq
            ch = choices{iseq};
            nsmp = numel(ch);
            for ismp = 1:nsmp-1
                sprevch(iseq,ismp) = sum(ch(1:ismp) == ch(ismp));
                srepeat(iseq,ismp) = ch(ismp) == ch(ismp+1);
            end
        end
        max_seen = max(sprevch(:),[],'omitnan');
        for idx = 1:max_seen
            ich = sprevch == idx;
            spstay_human(s,ct,idx) = mean(srepeat(ich),'omitnan');
        end

        % Human policy-guided choices and evidence-dependent repetition
        mvopt = cell(nseq,1);
        mcopt = cell(nseq,1);
        psw = [];
        for iseq = 1:nseq

            ch = choices{iseq};
            c = colvals{iseq}'*cfac;

            xc = zeros(size(c,1),2);
            xc(2:end,:) = cumsum(c(1:end-1,:),1,'omitnan');

            [~,tempopt] = min(abs(xc),[],2);
            mcopt{iseq} = [ch == tempopt',nan(1,nsmpMax-numel(ch))];
            mcopt{iseq}(abs(xc(:,1)) == abs(xc(:,2))) = nan;

        end % sequence

        dir_c_human(s,ct,:) = mean(cell2mat(mcopt),1,'omitnan');

        %%% guess accuracy
        mean_acc = mean(vertcat(guesspc{:}),2);
        guess_acc(s,ct,1:4) = arrayfun(@(l) mean(mean_acc(nsample==l)), length_list);

        tmp = vertcat(guesspc{:});
        guess_acc(s,ct,5) = mean(tmp(:));

    end % choicetype

end % subj

size(dir_c_human);
size(spstay_human);
size(guess_acc);

pRepeatNext = spstay_human;
pUncertainty = dir_c_human;

% remove low-performing subjects
data_grandAvg = mean(guess_acc(:,:,5),2);
rmv = data_grandAvg <= acc_thres;

unique_ids(rmv)

%

unique_ids(rmv) = [];

pRepeatNext(rmv,:,:) = [];
pUncertainty(rmv,:,:) = [];
guess_acc(rmv,:,:) = [];

Age(rmv,:) = [];
Sex(rmv,:) = [];


close all; clc
nsubj = size(guess_acc,1);
fprintf('Good-performing subjects: n = %d\n\n', nsubj)

data_nsmp = guess_acc(:,:,1:4);
data_mean = guess_acc(:,:,5);

% plot final probe accuracy by sequence length

configALL
col = [];
orange = [1,0.5,0];
col(1,:) = guess; % free: orange
col(2,:) = ones(1,3)*0.4; % cued (S)
col(3,:) = ones(1,3)*0.6; % cued (NS)

figure('position',[420   274   958   464])

ax = subplot(2,4,1);
ylimrange = [0.3,1];

liim = 10;

lw = [1.5, 1.5, 0.5];
lstyle = {'-','-','-.'};
alpha_level = [0.4,0.4,0.2];
for whichtype = 1:3
    data = squeeze(pRepeatNext(:,whichtype,:));
    nsubj = size(data,1);
    hold on
    x_ax     = 1:liim;
    % sphat    = bsxfun(@minus,data,mean(data(:,x_ax),2,'omitnan')); % within-participant version (replaced)
    X_patch  = [x_ax, fliplr(x_ax)];
    % yup      = mean(data(:,x_ax),'omitnan') + ( std( sphat(:,x_ax),'omitnan') / sqrt(nsubj)*sd ) ;
    % ylo      = mean(data(:,x_ax),'omitnan') - ( std( sphat(:,x_ax),'omitnan') / sqrt(nsubj)*sd ) ;
    % 95% CI across participants, at each point
    D        = data(:,x_ax);
    nD       = sum(~isnan(D),1);   % participants with data at each point
    yup      = mean(D,'omitnan') + std(D,'omitnan')./sqrt(nD)*sd;
    ylo      = mean(D,'omitnan') - std(D,'omitnan')./sqrt(nD)*sd;
    Y_patch  = [yup,flip(ylo)];
    fill(X_patch, Y_patch , 1, 'facecolor', 0.5*(col(whichtype,:)+1), 'edgecolor','none', 'facealpha', alpha_level(whichtype));
    plot(x_ax, mean(data(:,x_ax),'omitnan'), lstyle{whichtype}, 'Color', col(whichtype,:), 'LineWidth', lw(whichtype));
end
xlabel('times seen before')
ylabel(sprintf('p(repeat next)'));
set(ax,'xtick',[1,4,7,10],'ytick',0.5:0.25:1)
set(gca,'color','none','linewidth',1,'tickdir','out','fontsize',fs)
ylim(ylimrange)
xlim([0.5,liim])
txt_left = 1;
txt_fs = fs/1.2;
text(txt_left,1.02,'cued (S: streaking)','color',col(2,:),'FontSize',txt_fs)
text(txt_left,0.83,'free','color',col(1,:),'FontSize',txt_fs)
col_faded = (1 - 0.5) * [1 1 1] + 0.5 * col(3,:);
text(txt_left,0.4,{'cued (NS:'; 'non-streaking)'},'color',col_faded,'FontSize',txt_fs)


ax = subplot(2,4,2);
ylimrange = [0,1];
liim = 20;
for whichtype = 1:3
    data = squeeze(pUncertainty(:,whichtype,:));
    nsubj = size(data,1);
    hold on
    x_ax     = 2:liim;
    % sphat    = bsxfun(@minus,data,mean(data(:,x_ax),2,'omitnan')); % within-participant version (replaced)
    X_patch  = [x_ax, fliplr(x_ax)];
    % yup      = mean(data(:,x_ax),'omitnan') + ( std( sphat(:,x_ax),'omitnan') / sqrt(nsubj)*sd ) ;
    % ylo      = mean(data(:,x_ax),'omitnan') - ( std( sphat(:,x_ax),'omitnan') / sqrt(nsubj)*sd ) ;
    % 95% CI across participants, at each point
    D        = data(:,x_ax);
    nD       = sum(~isnan(D),1);   % participants with data at each point
    yup      = mean(D,'omitnan') + std(D,'omitnan')./sqrt(nD)*sd;
    ylo      = mean(D,'omitnan') - std(D,'omitnan')./sqrt(nD)*sd;
    Y_patch  = [yup,flip(ylo)];
    fill(X_patch, Y_patch , 1, 'facecolor', 0.5*(col(whichtype,:)+1), 'edgecolor','none', 'facealpha', alpha_level(whichtype));
    plot(x_ax, mean(data(:,x_ax),'omitnan'), lstyle{whichtype}, 'Color', col(whichtype,:), 'LineWidth', lw(whichtype));
end
xlabel('sampling trial')
ylabel('p(policy-guided choice)');
set(gca,'color','none','linewidth',1,'tickdir','out','fontsize',fs)
set(gca,'xtick',[2,8:4:20],'xticklabelrotation',0,'ytick',[0.0,0.5,1])
set(gca,'color','none','linewidth',1,'tickdir','out','fontsize',fs)
ylim(ylimrange)
xlim([0.5,liim])
plot([0,20],[0.5,0.5],'--','LineWidth',1,'color',chancecolor)
title_name = 'uncertainty guided';
tt = title(ax, title_name); 
tt.FontWeight = 'normal'; 
tt.Color = ones(1,3)*0.5;



subplot(2,4,3);
m = squeeze(mean(data_nsmp,1,'omitmissing'));
se = squeeze(std(data_nsmp,0,1,'omitmissing')) ./ sqrt(nsubj);
cfg           = [];
cfg.linewidth = lw(1);
cfg.alpha     = alpha_level(1)/2;
cfg.plotdots  = 0;
cfg.plotline  = true;
cfg.shading   = true;
cfg.doSE = 1;
cfg.dotsize = ms;

h(1) = plotpatch(squeeze(data_nsmp(:,1,:)),length_list,col(1,:),cfg); hold on

h(2) = errorbar(length_list,m(2,:),se(2,:),'ko', ...
    'markerfacecolor', col(2,:), ...
    'markersize', ms, ...
    'linewidth', 1, ...
    'CapSize', 0);

h(3) = errorbar(length_list,m(3,:),se(3,:),'o', ...
    'markerfacecolor', 'w', ...
    'markersize', ms, ...
    'linewidth', 1, ...
    'CapSize', 2, ...
    'color', col(3,:));

legend(h,condLabels,'location','nw','color','none','box','off');

ylabel('guess accuracy')
xlabel('sequence length')
set(gca,'xtick',length_list,'xticklabel',length_list)
lower_bound = 0.7;

upperlim = 0.9;
ylim([lower_bound,upperlim]);
xlim([1,20])
set(gca,'box','off','tickdir','out','color','none','linewidth',1,'fontsize',fs)
set(gca,'ytick',0.7:0.1:0.9)


ax = subplot(2,4,4);
ypos = ones(1,3)*lower_bound*1.005;
barcol = [col(1,:);col(2,:);1,1,1];
barcol_edge = col;
% mse = [];
condLabels_bar = {'','S','NS'};
for whichtype = 1:3
    data = squeeze(data_mean(:,whichtype,:));
    c = barcol(whichtype,:);
    b = bar(whichtype,mean(data),'FaceColor',c,'EdgeColor',barcol_edge(whichtype,:),'linewidth',barlw*1.5);
        b.FaceAlpha = alpha;
        b.EdgeAlpha = alpha*4;
        hold on
    errorbar(whichtype,mean(data),std(data)/sqrt(nsubj)*sd,'color', ...
        barcol_edge(whichtype,:), 'linewidth', barlw*1.5, 'CapSize', 0)

    text(whichtype, ypos(whichtype), condLabels_bar{whichtype}, ...
         'HorizontalAlignment', 'center', 'Rotation', 0, ...
         'VerticalAlignment', 'baseline',...
         'Color',col(whichtype,:), 'FontSize', fs);
    % mse(whichtype,:) = [mean(data)-std(data)/sqrt(nsubj),mean(data)+std(data)/sqrt(nsubj)];

    % data distribution:
    noise = [];
    cfg = [];
    cfg.noiseSD = 6;
    cfg.dotalpha = 0.1;
    cfg.color = col;
    cfg.markersize = 25;

    tmp    = data;
    [f,xi] = ksdensity(tmp);
    f      = f./max(f);
    ff     = [];
    for j = length(tmp):-1:1
        [~,id] = min(abs(tmp(j)-xi));
        ff(j)  = f(id);
    end
    for j = length(ff):-1:1
        noise(j,1) = randn*ff(j)/cfg.noiseSD;
    end
    scatter(whichtype+noise,data,cfg.markersize,'o',...
            'MarkerFaceColor', cfg.color(whichtype,:), ...
            'MarkerEdgeColor', cfg.color(whichtype,:), ...
            'MarkerFaceAlpha', cfg.dotalpha, ... % Set alpha transparency for marker face
            'MarkerEdgeAlpha', cfg.dotalpha);    % Set alpha transparency for marker edge
            hold on;

% density outline
width = 0.4;
[fd,xd] = ksdensity(data,'NumPoints',500);
fd = fd./max(fd)*width;

% plot(whichtype + fd, xd, 'Color',cfg.color(whichtype,:), 'LineWidth',0.5);
% plot(whichtype - fd, xd, 'Color',cfg.color(whichtype,:), 'LineWidth',0.5);

% full violin outline (use instead)
% plot(whichtype + [fd, -fliplr(fd)], [xd, fliplr(xd)], ...
%     'Color',cfg.color(whichtype,:), 'LineWidth',0.8);
    
end

set(ax, 'box', 'off', ...
    'color', 'none', ...
    'tickdir', 'out', ...
    'fontsize', fs, ...
    'XTick', [],'linewidth',1.,'ytick',[0.7, 0.85, 1.0]);
set(ax,'xticklabel',{'free','cued','cued'},'xtick',[1,2,3])

ylim(ax, [lower_bound, 1]);
ylabel(ax, 'mean guess accuracy');
xlabel(ax, 'sampling choice type')
off = 0.3;
xlim(ax,[off,4-off])
% plot([2,2],[mse(2,1),mse(2,2)]+(mse(2,2)-mse(2,1))*1.5,'k')
% plot([3,3],[mse(3,1)+(mse(2,2)-mse(2,1))*1.5,(mse(2,2)+(mse(2,2)-mse(2,1))*1.5)],'k')

% plot([2,3],ones(1,2)*0.89,'k')
% plot([1,3],ones(1,2)*0.9,'k')

h = 0.006;   % height of vertical ticks
x = [1, 3];
y = 1;
plot(x, [y y], 'k')
plot([x(1) x(1)], [y-h y], 'k')
plot([x(2) x(2)], [y-h y], 'k')

x = [2, 3];
y = 0.98;
plot(x, [y y], 'k')
plot([x(1) x(1)], [y-h y], 'k')
plot([x(2) x(2)], [y-h y], 'k')



% text(2.5,0.89,'*','HorizontalAlignment','Center',...
%                 'BackGroundColor','none','VerticalAlignment','middle',...
%                 'fontsize',16,'color',darkred); hold on;
% text(2,0.9,'*','HorizontalAlignment','Center',...
%                 'BackGroundColor','none','VerticalAlignment','middle',...
                % 'fontsize',16,'color',darkred); hold on;

set(gcf, 'Renderer', 'painters'); %
set(gcf, 'PaperPositionMode', 'auto');


%
% close all; clc
figure('position',[763   151   511   464])

contra = data_mean(:,1:2)-data_mean(:,3);
ax = subplot(2,4,1);

% data distribution:
    noise = [];
    cfg = [];
    cfg.noiseSD = 6;
    cfg.dotalpha = 0.1;
    cfg.color = col;
    cfg.markersize = 30;

    for i = 1:2
    tmp    = contra(:,i);
    [f,xi] = ksdensity(tmp);
    f      = f./max(f);
    ff     = [];
    for j = length(tmp):-1:1
        [~,id] = min(abs(tmp(j)-xi));
        ff(j)  = f(id);
    end
    for j = length(ff):-1:1
        noise(j,1) = randn*ff(j)/cfg.noiseSD;
    end
    scatter(i+noise,tmp,cfg.markersize,'o',...
            'MarkerFaceColor', cfg.color(i,:), ...
            'MarkerEdgeColor', cfg.color(i,:), ...
            'MarkerFaceAlpha', cfg.dotalpha, ... % Set alpha transparency for marker face
            'MarkerEdgeAlpha', cfg.dotalpha);    % Set alpha transparency for marker edge
            hold on;

    errorbar(i,mean(tmp),std(tmp)/sqrt(nsubj)*sd,...
        'ko','markerfacecolor', cfg.color(i,:),'capsize',0,'LineWidth',1)
    end

plot([0,3],[0,0],'--','color','k')
ylim([-0.2,+0.2])
xlim([0.5,2.5])
ylabel('\Delta accuracy')

set(ax, 'box', 'off', ...
    'color', 'none', ...
    'tickdir', 'out', ...
    'fontsize', fs, ...
    'XTick', [],'linewidth',1.,'ytick',[-0.2, 0, 0.2]);
set(ax, 'box', 'off', ...
    'color', 'none', ...
    'tickdir', 'out', ...
    'fontsize', fs, ...
    'YAxisLocation', 'right', ...
    'XTick', [], ...
    'linewidth', 1., ...
    'ytick', [-0.2, 0, 0.2]);
h = ylabel('\Delta accuracy', 'Rotation', -90);
h.Position(1) = h.Position(1) + 0.45;
set(ax,'xticklabel',{'free – NS','S – NS'},'xtick',[1,2],'xticklabelrotation',0)
xlabel(ax, 'sampling choice type')
set(ax,'XColor','none')
set(gcf, 'Renderer', 'painters'); %
set(gcf, 'PaperPositionMode', 'auto');




clc;
% ttest
% Pairwise comparisons
pairs = [1 3; 2 3];
np = size(pairs,1);
[p, t, df, dz] = deal(nan(1,np));
for i = 1:np
    contra = data_mean(:,pairs(i,1)) - data_mean(:,pairs(i,2));
    [~,p(i),~,stats] = ttest(contra);
    t(i)  = stats.tstat;
    df(i) = stats.df;
    dz(i) = mean(contra,'omitnan') / std(contra,'omitnan');
end
[p_corr,h] = Bonf_Holm_yc(p,0.05);

fprintf('\nTwo-sided paired t-tests, Holm corrected\n');
fprintf('Pair\tt\tdf\td_z\tp\tp_corr\n');
for i = 1:np
    fprintf('%d vs %d\t%.2f\t%d\t%.2f\t%.4f\t%.4f\n', ...
        pairs(i,1), pairs(i,2), t(i), df(i), dz(i), p(i), p_corr(i));
end


% [h,p,ci,stats] = ttest(squeeze(data_nsmp(:,2,:)-data_nsmp(:,3,:)));
% stats
% p
% [p_corr,h] = Bonf_Holm_yc(p,0.05)

seq = [8 12 16 20];
dd = squeeze(data_nsmp(:,2,:) - data_nsmp(:,3,:));   % subjects x lengths
dd = [dd, mean(dd,2)];                                % last column = across-length mean

[~,p,~,stats] = ttest(dd);
p_corr = p;
[p_corr(1:4), h] = Bonf_Holm_yc(p(1:4), 0.05);       % Holm only across the 4 lengths
dz = mean(dd,'omitnan') ./ std(dd,'omitnan');         % Cohen's d_z for paired data

lab = [arrayfun(@num2str, seq, 'uni', 0), {'mean'}];
fprintf('\nTwo-sided paired t-tests (cond 2 vs 3)\n');
fprintf('Seq\tt\tdf\td_z\tp\n');
for i = 1:numel(lab)
    fprintf('%s\t%.2f\t%d\t%.2f\t%.4f\n', lab{i}, stats.tstat(i), stats.df(i), dz(i), p_corr(i));
end

