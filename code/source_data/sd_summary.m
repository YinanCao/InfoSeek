function T = sd_summary(D, xname, xval, varargin)
% SD_SUMMARY  Mean and error bounds across participants (rows of D), one row per column of D.
%   Default: 95% CI = mean +/- 1.96 x SD / sqrt(number of rows of D), as plotted.
%   Options (name-value):
%     'N'     'rows' (default) or 'valid': divide by the number of rows, or by the
%             number of non-missing values in each column (as in fig7abcd.m/fig7efgh.m panels b, e, f).
%     'Error' 'CI95' (default) or 'SEM' (mean +/- 1 SEM, as in Fig. 7g).
p = inputParser;
addParameter(p, 'N', 'rows');
addParameter(p, 'Error', 'CI95');
parse(p, varargin{:});
n  = sum(~isnan(D), 1)';
m  = mean(D, 1, 'omitnan')';
sd = std(D, 0, 1, 'omitnan')';
if strcmpi(p.Results.N, 'valid'), se = sd ./ sqrt(n); else, se = sd ./ sqrt(size(D, 1)); end
if strcmpi(p.Results.Error, 'SEM')
    T = table(xval(:), n, m, se, m - se, m + se, ...
              'VariableNames', {xname, 'n', 'mean', 'SEM', 'mean_minus_SEM', 'mean_plus_SEM'});
else
    hw = 1.96 * se;
    T = table(xval(:), n, m, m - hw, m + hw, ...
              'VariableNames', {xname, 'n', 'mean', 'CI95_lower', 'CI95_upper'});
end
end
