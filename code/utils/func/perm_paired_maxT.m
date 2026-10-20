function out = perm_paired_maxT(X, nperm, alpha, tail)
% X: nSubj x nParam x 2
% nperm: number of permutations, default 10000
% alpha: significance level, default 0.05
% tail: 'both' (default) or 'right' or 'left'
%
% out fields:
%   t_obs          1 x nParam observed t
%   p_unc          1 x nParam uncorrected permutation p
%   p_corr         1 x nParam maxT FWER corrected p
%   h              1 x nParam significance at alpha using p_corr
%   dz             1 x nParam Cohen's dz for paired design
%   crit_t_corr    scalar two sided or one sided familywise threshold
%   details        struct with sizes and options

    if nargin < 2 || isempty(nperm), nperm = 10000; end
    if nargin < 3 || isempty(alpha), alpha = 0.05; end
    if nargin < 4 || isempty(tail), tail = 'both'; end

    [nSubj, nParam, nCond] = size(X);
    assert(nCond == 2, 'X must have size nSubj x nParam x 2');
    if any(isnan(X(:)))
        error('NaNs detected. Please remove or impute before running.');
    end

    % paired differences, cond1 − cond2
    D = X(:,:,1) - X(:,:,2);                      % nSubj x nParam
    mu = mean(D, 1);                              % 1 x nParam
    sd = std(D, 0, 1);                            % 1 x nParam
    t_obs = mu ./ (sd ./ sqrt(nSubj));            % 1 x nParam
    dz = mu ./ sd;                                % 1 x nParam, Cohen''s dz

    % permutation by sign flipping within subjects
    % R is nperm x nSubj with entries ±1
    R = 2*(rand(nperm, nSubj) > 0.5) - 1;
    % ensure the first row uses all +1 to include the unpermuted mapping
    R(1,:) = 1;

    % denominator is constant across permutations under sign flips
    denom = sd ./ sqrt(nSubj);                    % 1 x nParam

    % permuted means across subjects: (R * D) / nSubj
    m_perm = (R * D) / nSubj;                     % nperm x nParam
    t_perm = m_perm ./ denom;                     % nperm x nParam

    % max statistic across parameters per permutation
    switch lower(tail)
        case 'both'
            maxstat = max(abs(t_perm), [], 2);    % nperm x 1
            thr_side = @(v) abs(v);
        case 'right'
            maxstat = max(t_perm, [], 2);
            thr_side = @(v) v;
        case 'left'
            maxstat = max(-t_perm, [], 2);
            thr_side = @(v) -v;
        otherwise
            error('tail must be ''both'', ''right'', or ''left''');
    end

    % corrected p values using maxT null
    t_use = thr_side(t_obs);                      % 1 x nParam
    % add 1 for stability and to include observed configuration
    p_corr = (sum(maxstat >= t_use, 1)) ./ nperm; % 1 x nParam

    % uncorrected permutation p values (parameterwise sign flips)
    switch lower(tail)
        case 'both'
            p_unc = mean(abs(t_perm) >= abs(t_obs), 1);
        case 'right'
            p_unc = mean(t_perm >= t_obs, 1);
        case 'left'
            p_unc = mean(t_perm <= t_obs, 1);
    end

    % familywise critical t threshold from maxT at 1 − alpha
    q = quantile(maxstat, 1 - alpha);
    switch lower(tail)
        case 'both'
            crit_t_corr = q;                      % compare to |t|
        otherwise
            crit_t_corr = q;                      % one sided threshold
    end

    h = p_corr < alpha;

    out = struct();
    out.t_obs       = t_obs;
    out.p_unc       = p_unc;
    out.p_corr      = p_corr;
    out.h           = h;
    out.dz          = dz;
    out.crit_t_corr = crit_t_corr;
    out.details     = struct('nSubj', nSubj, 'nParam', nParam, ...
                             'nperm', nperm, 'alpha', alpha, 'tail', tail);
end
