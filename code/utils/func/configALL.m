
fs = 14;
ms = 9;
alpha = 0.2;
barlw = 1.5;
siglw = 4;

c = lines;
match = c(4,:);
guess = c(5,:);
condcolor = {match,guess};
chancecolor = ones(1,3)*0.75;
darkred = [0.5 0 0];

lstyle = {'-.','-'};