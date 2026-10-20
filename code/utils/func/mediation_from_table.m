function OUT = mediation_from_table(T, varargin)
% MEDIATION_FROM_TABLE
% Mediation in two directions using variables already in table T
% Model A: X = betac, M = EoS,  Y = acc
% Model B: X = EoS,   M = betac, Y = acc
% Controls included in every equation, default: leak, noise, age, sex
%
% Now reports 95% confidence intervals instead of SEs

% Options
p = inputParser;
addParameter(p, 'Y', 'acc');
addParameter(p, 'X1','betac');      % for Model A
addParameter(p, 'M1','EoS');        % for Model A
addParameter(p, 'Controls', {'betar','leak','noise','age','sex'});
addParameter(p, 'NBoot', 5000);
addParameter(p, 'RobustSE', true);
addParameter(p, 'Alpha', 0.05);
addParameter(p, 'Verbose', true);
parse(p, varargin{:});

Yname    = string(p.Results.Y);
X1name   = string(p.Results.X1);
M1name   = string(p.Results.M1);
ctrl     = string(p.Results.Controls(:))';
nboot    = p.Results.NBoot;
robustSE = p.Results.RobustSE;
alpha    = p.Results.Alpha;
verbose  = p.Results.Verbose;

% Pull columns directly
Y  = T.(Yname);
X1 = T.(X1name);
M1 = T.(M1name);
C  = table2array(T(:, cellstr(ctrl)));

% Run both directions on the same rows
OUT.modelA = run_one(Y, X1, M1, C, ...
    sprintf('%s to %s, mediator = %s', X1name, Yname, M1name), nboot, robustSE, alpha);

OUT.modelB = run_one(Y, M1, X1, C, ...
    sprintf('%s to %s, mediator = %s', M1name, Yname, X1name), nboot, robustSE, alpha);

OUT.combinedTable = [OUT.modelA.table; OUT.modelB.table];

if verbose
    fprintf('\n===== Mediation with controls: %s =====\n', strjoin(cellstr(ctrl), ', '));
    print_model(OUT.modelA, alpha);
    print_model(OUT.modelB, alpha);
end

end

% ========= Subfunctions =====================================

function MOUT = run_one(Y, X, M, C, label, nboot, robust, alpha)
n = size(Y,1);
one = ones(n,1);

% Path a
Xa = [one, X, C];
[ba,sea,ta,pa,R2a,dfa] = ols(Xa, M, robust);
a = ba(2); sea = sea(2); ta = ta(2); pa = pa(2);
CI_a = ci_from_se(a, sea, dfa, alpha);

% Paths b and c prime
Xbcp = [one, X, M, C];
[bb,seb,tb,pb,R2b,dfb] = ols(Xbcp, Y, robust);
cprime = bb(2); secp = seb(2); tcp = tb(2); pcp = pb(2);
b      = bb(3); sebm = seb(3); tbm = tb(3); pbm = pb(3);
CI_b      = ci_from_se(b, sebm, dfb, alpha);
CI_cprime = ci_from_se(cprime, secp, dfb, alpha);

% Total c
Xc = [one, X, C];
[bc,sec,tc,pc,R2c,dfc] = ols(Xc, Y, robust);
ctotal = bc(2); sec = sec(2); tc = tc(2); pc = pc(2);
CI_ctotal = ci_from_se(ctotal, sec, dfc, alpha);

% Indirect a*b with bootstrap
ab_hat = a*b;
ab_boot = nan(nboot,1);
idx = (1:n)';
for i = 1:nboot
    ii = idx(randi(n, n, 1));
    Xi = X(ii); Mi = M(ii); Yi = Y(ii); Ci = C(ii,:);
    o  = ones(n,1);
    % a*
    ba_i = ([o, Xi, Ci]'*[o, Xi, Ci]) \ ([o, Xi, Ci]'*Mi);
    a_i  = ba_i(2);
    % b*
    bb_i = ([o, Xi, Mi, Ci]'*[o, Xi, Mi, Ci]) \ ([o, Xi, Mi, Ci]'*Yi);
    b_i  = bb_i(3);
    ab_boot(i) = a_i * b_i;
end
CI_indirect = quantile(ab_boot, [0.025, 0.975]);
pboot = 2*min(mean(ab_boot <= 0), mean(ab_boot >= 0));

% Package
MOUT.label = label;
MOUT.paths = struct();
MOUT.paths.a        = pack_path('a',        a,   ta, pa, R2a, dfa, n, CI_a);
MOUT.paths.b        = pack_path('b',        b,   tbm, pbm, R2b, dfb, n, CI_b);
MOUT.paths.c_total  = pack_path('c_total',  ctotal, tc, pc, R2c, dfc, n, CI_ctotal);
MOUT.paths.c_prime  = pack_path('c_prime',  cprime, tcp, pcp, R2b, dfb, n, CI_cprime);
MOUT.indirect.beta  = ab_hat;
MOUT.indirect.CI    = CI_indirect(:)';
MOUT.indirect.p     = pboot;

% Tidy table
modelCol = repmat(string(label), 5, 1);
pathCol  = ["a"; "b"; "c_prime"; "c_total"; "indirect_ab"];
betaCol  = [a; b; cprime; ctotal; ab_hat];
tCol     = [ta; tbm; tcp; tc; NaN];
pCol     = [pa; pbm; pcp; pc; pboot];
CIcol    = [CI_a; CI_b; CI_cprime; CI_ctotal; CI_indirect];

MOUT.table = table( ...
    modelCol, pathCol, betaCol, tCol, pCol, CIcol, ...
    'VariableNames', {'model','path','beta','t','p','CI_95'});

end

function [b,se,tv,pv,R2,df] = ols(X, y, robust)
n = size(X,1); k = size(X,2);
invXX = (X' * X) \ eye(k);
b = invXX * (X' * y);
res = y - X*b;
SST = sum((y - mean(y)).^2);
if ~robust
    sigma2 = sum(res.^2) / max(1, n - k);
    V = sigma2 * invXX;
else
    Hdiag = sum((X * invXX) .* X, 2);        % hat diagonals
    W = (res.^2) ./ ((1 - Hdiag).^2 + eps);  % HC3
    V = invXX * (X' * (X .* W)) * invXX;
end
se = sqrt(max(eps, diag(V)));
tv = b ./ se;
df = n - k;
pv = 2 * (1 - tcdf(abs(tv), df));
R2 = 1 - sum(res.^2) / max(eps, SST);
end

function CI = ci_from_se(beta, se, df, alpha)
if nargin < 4 || isempty(alpha), alpha = 0.05; end
tcrit = tinv(1 - alpha/2, df);
CI = [beta - tcrit*se, beta + tcrit*se];
end

function S = pack_path(name, beta, t, p, R2, df, nobs, CI95)
S = struct('name',name,'beta',beta,'t',t,'p',p, ...
           'R2',R2,'df',df,'n',nobs,'CI95',CI95);
end

function print_model(M, alpha)
fprintf('\n--- %s ---\n', M.label);
fprintf('Path a        beta = %.4f, 95%% CI [%.4f, %.4f], t(%d) = %.2f, p = %.3g %s\n', ...
    M.paths.a.beta, M.paths.a.CI95(1), M.paths.a.CI95(2), M.paths.a.df, M.paths.a.t, M.paths.a.p, sigmark(M.paths.a.p,alpha));
fprintf('Path b        beta = %.4f, 95%% CI [%.4f, %.4f], t(%d) = %.2f, p = %.3g %s\n', ...
    M.paths.b.beta, M.paths.b.CI95(1), M.paths.b.CI95(2), M.paths.b.df, M.paths.b.t, M.paths.b.p, sigmark(M.paths.b.p,alpha));
fprintf('Direct c''     beta = %.4f, 95%% CI [%.4f, %.4f], t(%d) = %.2f, p = %.3g %s\n', ...
    M.paths.c_prime.beta, M.paths.c_prime.CI95(1), M.paths.c_prime.CI95(2), M.paths.c_prime.df, M.paths.c_prime.t, M.paths.c_prime.p, sigmark(M.paths.c_prime.p,alpha));
fprintf('Total c       beta = %.4f, 95%% CI [%.4f, %.4f], t(%d) = %.2f, p = %.3g %s\n', ...
    M.paths.c_total.beta, M.paths.c_total.CI95(1), M.paths.c_total.CI95(2), M.paths.c_total.df, M.paths.c_total.t, M.paths.c_total.p, sigmark(M.paths.c_total.p,alpha));
fprintf('Indirect a*b  beta = %.4f, 95%% CI [%.4f, %.4f], bootstrap p = %.3g %s\n', ...
    M.indirect.beta, M.indirect.CI(1), M.indirect.CI(2), M.indirect.p, sigmark(M.indirect.p,alpha));
end

function s = sigmark(p, alpha)
if p < 0.001
    s = '***';
elseif p < 0.01
    s = '**';
elseif p < 0.05
    s = '*';
else
    s = '';
end
end

function out = pval2stars(p)
    if p < 1e-4
        out = '< 0.0001';
    elseif p < 1e-3
        out = '< 0.001';
    elseif p < 0.01
        out = '< 0.01';
    elseif p < 0.05
        out = num2str(p);
    else
        out = sprintf('%.3f', p);
    end
end