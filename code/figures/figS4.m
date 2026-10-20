clear;clc;close all;

dataset = 'COLINE';
subjID  = 1:420;
% load human data;
load(['dat_choicestbl_',dataset,'.mat'],'choicestbl');
choicestbl(choicestbl.excludepart == true,:) = [];
data = choicestbl;
unique_ids = unique(data.subj);
nsubj = length(unique_ids);
nsmpMax = 20;
seqLength = [8,12,16,20];
cfac = 1.4386;
cond = 1; % arbitrary
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Loop over each unique subject ID
for s = nsubj:-1:1
    disp(['simulating subject #',num2str(s)])
    subj_id = unique_ids(s);
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
    
    theta_set = [0,1,2,3];
    betac_set = [0,1,1000];
    
    epsilon = 0.9;
    gamma = 0;
    sigma = 0;
    delta_c = 0;
    delta_u = 0;
    betar = 0;
    betav = 0;

    for i = 1:length(theta_set)
        for j = 1:length(betac_set)
            theta = theta_set(i);
            betac = betac_set(j);
            for isim = 1:10
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
                    spstay_model(s,idx,isim,i,j) = mean(srepeat(ich),'omitnan');
                end
        
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
        
                    signed_evi = belief_aligned_evi;
                    psw = [psw; signed_evi, p_switch_next];
        
                end
    
                % bin:
                rmv = psw(:,1)==0 | isnan(psw(:,2));
                psw(rmv, :) = [];
                psw = round(psw, 5);
                evi_level = unique(psw(:,1));
                for lev_i = 1:length(evi_level)
                    pSW(s,lev_i,isim,i,j) = 1-mean(psw(psw(:,1)==evi_level(lev_i), 2));
                end
                dir_c(s,:,isim,i,j) = mean(cell2mat(mcopt),1,'omitnan');
    
            end % sim
        end % betac
    end % theta
end % subj

size(spstay_model)
out = squeeze(mean(mean(spstay_model,3,'omitnan'),1,'omitnan'));
size(out)

%% plot
clc;close all
size(dir_c)

i = 1; % theta = 0

dirc = squeeze(mean(mean(dir_c(:,:,:,i,:),3,'omitnan'),2,'omitnan'));
dirc = mean(dirc);
b_aligned = squeeze(mean(mean(pSW(:,:,:,i,:),3,'omitnan'),1,'omitnan'));

clc;close all
configALL

panel_w = 340;
panel_h = 220;

fs = 12;

figure('Position',[476   360   panel_w+15   panel_h])

n = 3;
c0 = ones(1,3)*0.7; % start: grey (adjust if you like)
c1 = guess;         % end: green
t = linspace(0, 1, n)';  % column vector
omega_color = c0.*(1 - t) + c1.*t;  % n-by-3 colormap

subplot(1,2,1)
for i = 1:3
    bar(i,dirc(i),'FaceColor',omega_color(i,:),'edgecolor','none'); hold on;
end
set(gca,'color','none','linewidth',1,'tickdir','out','fontsize',fs,'box','off')
set(gca,'xtick',[1,2,3],'ytick',0.5:0.25:1,'xticklabel',{'0','1',['+' char(8734)]},'xticklabelrotation',0)
xlim([1-0.5,4-0.5])
xlabel('\beta_c')
ylabel('p(uncertainty-guided choice)')

theta_w = linspace(2,6,length(theta_set));
subplot(1,2,2)
liim = length(evi_level);
xtick = round(evi_level([1,3,6,liim]),1);
xtick = [xtick(1),0,xtick(end)];

plot([0,0],[0.35,1],'k--','linewidth',0.5); hold on;
plot([0,0],[0.,0.04],'k-','linewidth',1);
hold on;
h = [];
for i = size(b_aligned,2):-1:1
    h(i) = plot(evi_level,b_aligned(:,i), 'Color', omega_color(i,:),'linewidth',theta_w(i)); hold on;
    ylim([0, 1])
    set(gca,'color','none','linewidth',1,'tickdir','out','fontsize',fs,'box','off')
    xlabel('signed evidence')
    ylabel('p(repeat next)')
end
lgd = legend(h,{'0','1',['+' char(8734)]},'box','on','color','none','location','sw','autoupdate','off');
lgd.LineWidth = 0.5;
set(gca,'xtick',xtick,'ytick',0.5:0.25:1,'xticklabel',{'-1.4','0','+1.4'},'xticklabelrotation',0)
of = 0.02;
xlim([-1.48-of,1.48+of])
text(-0.7,0.37,'\beta_c','fontsize',12)


figure('Position',[476   360+50   panel_w   panel_h])
n = 4;
c0 = ones(1,3)*0.7;          
c1 = guess/1.8;   
t = linspace(0, 1, n)';          % column vector
omega_color = c0.*(1 - t) + c1.*t;  % n-by-3 colormap

for i = 1:length(theta_set)
    for j = 1

        plot(out(:,i,j), 'Color', omega_color(i,:),'linewidth',theta_w(i)); hold on;
        
        xtick = [1,4,7,10];
        set(gca,'xtick',xtick,'ytick',0.5:0.25:1)
        xlim([0.5,10])
        set(gca,'color','none','linewidth',1,'tickdir','out','fontsize',fs,'box','off','xticklabelrotation',0)
        xlabel('times seen before')
        ylabel('p(repeat next)')
        ylim([0., 1])
        text(1.5,0.42,'\theta','fontsize',12)
        
    end
end
legend(num2str(theta_set'),'box','on','color','none','location','sw','linewidth',0.5);
set(gcf, 'Renderer', 'painters'); %
set(gcf, 'PaperPositionMode', 'auto');
