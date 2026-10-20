clear; close all; clc
fs = 14;
fig = figure('Position',[476 410 320 250]);
ax = axes(fig);
hold(ax,'on')
nsmp = 20;
theta = 1.5;
belief = [
    0              0
    -0.3892        0
    0.2431         0
    1.0099         0
    0.5467         0
    1.5724         0
    1.5724    1.0185
    1.5724   -0.0475
    1.5724   -0.1539
    1.5724   -1.1725
    1.5724   -1.3005
    1.5724   -2.6211
    1.0876   -2.6211
    1.2746   -2.6211
    2.4240   -2.6211
    3.2110   -2.6211
    3.2110   -2.1593
    3.2110   -1.4616
    3.2110   -2.5118
    3.2110   -2.8686
    3.2110   -2.2672];
choice = [1 1 1 1 1 2 2 2 2 2 2 1 1 1 1 2 2 2 2 2]';
ev  = diff(belief);          % 20x2 single-trial evidence
% mev = max(abs(ev(:)));       % |evidence| >= mev gives pure blue/orange
mev = 1.4386;

plot([5,5],[-4 4],'-','color','k','LineWidth',1)
plot([11,11],[-4 4],'-','color','k','LineWidth',1)
plot(ax,[0 nsmp],[theta theta],'color',ones(1,3)*0.75,'LineWidth',1.2);
plot(ax,[0 nsmp],[-theta -theta],'color',ones(1,3)*0.75,'LineWidth',1.2);
plot(ax,[0 nsmp],[0 0],'--','color',ones(1,3)*0.75,'LineWidth',1.2);

% Belief trajectories
plot(ax,0:5,belief(1:6,1),'-','LineWidth',3,'color','k');
plot(ax,0:5,belief(1:6,2),'-','LineWidth',.5,'color','k');
plot(ax,5:11,belief(6:12,2),'-','LineWidth',3,'color','k');
plot(ax,5:11,belief(6:12,1),'-','LineWidth',.5,'color','k');
plot(ax,11:15,belief(12:16,1),'-','LineWidth',3,'color','k');
plot(ax,11:15,belief(12:16,2),'-','LineWidth',.5,'color','k');
plot(ax,15:20,belief(16:21,2),'-','LineWidth',3,'color','k');
plot(ax,15:20,belief(16:21,1),'-','LineWidth',.5,'color','k');

% Option 2: triangles colored by evidence
c = belief(2:end,2); c(choice~=2) = nan;
idx = find(~isnan(c));
for j = idx'
    col = evidenceColor(ev(j,2),mev);
    plot(ax,j,c(j),'^','MarkerSize',15,'MarkerFaceColor',col,'MarkerEdgeColor','k','LineWidth',1);
end

ylim(ax,[-4 4]); xlim(ax,[0 nsmp])
set(ax,'color','none','linewidth',1,'tickdir','out','fontsize',fs,'box','off','xtick',[1 8,12,16,20],'xticklabelrotation',0)
xlabel(ax,'sampling trial')
ylabel(ax,'belief')

% Option 1: pentagons colored by evidence
drawPentagons(ax,belief,choice,ev,mev);
% Redraw pentagons whenever figure is resized
fig.SizeChangedFcn = @(~,~) drawPentagons(ax,belief,choice,ev,mev);
set(fig,'PaperPositionMode','auto');

%%
function drawPentagons(ax,belief,choice,ev,mev)
    delete(findobj(ax,'Tag','pentagonMarker'));
    c = belief(2:end,1); c(choice~=1) = nan;
    idx = find(~isnan(c));
    oldUnits = ax.Units; ax.Units = 'pixels'; pos = ax.Position; ax.Units = oldUnits;
    rPix = 8;
    rx = rPix*diff(ax.XLim)/pos(3);
    ry = rPix*diff(ax.YLim)/pos(4);
    ang = pi/2 + (0:4)*2*pi/5;
    for j = idx'
        col = evidenceColor(ev(j,1),mev);
        patch(ax,j+rx*cos(ang),c(j)+ry*sin(ang),col,'EdgeColor','k','LineWidth',1,'Tag','pentagonMarker');
    end
end

function col = evidenceColor(y,m)
    blue   = [0 0.5 1];
    gray   = [0.5 0.5 0.5];
    orange = [1 0.5 0];
    y = max(-m,min(m,y));
    if y < 0
        t = (y+m)/m;
        col = blue*(1-t) + gray*t;
    else
        t = y/m;
        col = gray*(1-t) + orange*t;
    end
end