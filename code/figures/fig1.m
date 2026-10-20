clear; clc; close all;
configALL

% number of colors for the colormap
n_colors = 256;  % smooth
% define anchors
blue   = [0.0, 0.5, 1.0];
gray   = [0.5, 0.5, 0.5];
orange = [1.0, 0.5, 0.0];

% build left (blue to gray)
n_left = round(n_colors/2);
cmap_left = [linspace(blue(1),gray(1),n_left)', ...
             linspace(blue(2),gray(2),n_left)', ...
             linspace(blue(3),gray(3),n_left)'];

% build right (gray to orange)
n_right = n_colors - n_left;
cmap_right = [linspace(gray(1),orange(1),n_right)', ...
              linspace(gray(2),orange(2),n_right)', ...
              linspace(gray(3),orange(3),n_right)'];

perr = 1/3; % error rate
cfac = get_cfac(perr);
x    = -1:0.001:+1;
x    = 0.5*(x(1:end-1)+x(2:end)); % bin centers
b    = fzero(@(p)trapz(x(x > 0),1./(1+exp(x(x > 0)*p))/trapz(x,1./(1+exp(x*p))))-perr,[0,1000]);
p1   = 1./(1+exp(-x*b));
p1   = p1/trapz(x,p1);

idx_neg = find(x<0);
idx_pos = find(x>=0);
cmap    = zeros(numel(x),3);

% left side: interpolate blue to gray
for c = 1:3
    cmap(idx_neg,c) = linspace(blue(c), gray(c), numel(idx_neg));
end
% right side: interpolate gray to orange
for c = 1:3
    cmap(idx_pos,c) = linspace(gray(c), orange(c), numel(idx_pos));
end

% plot
figure('Position',[442   570   606   210]);
hold on

P = {1-p1, p1};

for k = 1:2
    subplot(1,3,k)
    p = P{k};
    hold on;

    % fill under curve
    for i = 1:numel(x)-1
        fill_x = [x(i), x(i+1), x(i+1), x(i)];
        fill_y = [0, 0, p(i+1), p(i)];
        fill_color = cmap(i,:);
        fill(fill_x, fill_y, fill_color, 'EdgeColor', 'none');
    end
    plot([0,0],[0,0.5],'k--','LineWidth',1)

    xlim([-1 1])
    ylim([0 1])
    box off
    axis square
    set(gca,'color','none','linewidth',1,'tickdir','out')
    set(gca,'ytick',[0,0.5,1],'fontsize',fs,'xtick',[-1,0,1])
    xlabel('color shade')
   
    if k==1
        ylabel('probability density')
    end
end


subplot(1,3,3)

plot([-1,1],[-1,1]*cfac,'-','LineWidth',3,'Color',ones(1,3)*0.75)
xlim([-1 1])
hold on;
plot([-1,0],[0,0],'k--','LineWidth',1)
plot([0,0],[-cfac,0],'k--','LineWidth',1)
ylim([-cfac cfac]*1.1)
ylabel('evidence (logLR)')
box off
set(gca,'color','none','linewidth',1,'tickdir','out')
set(gca,'ytick',[-1,0,1],'fontsize',fs,'xtick','')

colormap(cmap);
colorbar;
cb = colorbar;
cb.Location = 'southoutside';   % horizontal and below x-axis
cb.Label.String = 'color shade';
clim([-1 1]);
cb.FontSize = fs;            % sets tick label font size
cb.Label.FontSize = fs*1.1;

set(gcf, 'Renderer', 'painters'); %
set(gcf, 'PaperPositionMode', 'auto');

%%
function [cfac] = get_cfac(perr)
    % get color-to-evidence factor
    x = -1:0.001:+1;
    cfac = fzero(@(b)trapz(x(x > 0),...
        1./(1+exp(x(x > 0)*b))/trapz(x,1./(1+exp(x*b))))-perr,[0,10]);
end