% function report_ttest_peak(D, baseline, tail, label)   % original
function report_ttest_peak(D, baseline, tail, label, trials)
% REPORT_TTEST_PEAK  One-sample t-test at each column of D (subjects x trials),
% FDR-corrected (Benjamini-Hochberg), reported at the peak t value.
% tail: 'right', 'left' or 'both'.
% trials (optional): trial number of each column of D, e.g. 2:20 when the
%   curve starts at trial 2. Default 1:size(D,2). The printed peak trial and
%   significant trials are taken from this vector, not the column index.
% If D has a single column (e.g. a mean over trials), no trial is printed.

    if nargin < 5 || isempty(trials)
        trials = 1:size(D, 2);
    end
    trials = trials(:)';
    assert(numel(trials) == size(D, 2), ...
        'report_ttest_peak: numel(trials) must equal size(D,2).');

    [~, p, ~, st] = ttest(D, baseline, 'Tail', tail);
    p    = squeeze(p);
    t    = squeeze(st.tstat);
    pFDR = mafdr(p(:), 'BHFDR', true);

    % Peak (largest t for 'right'/'both', smallest for 'left')
    if strcmp(tail, 'left')
        [tPeak, iPeak] = min(t);
    else
        [tPeak, iPeak] = max(t);
    end

    x      = D(:, iPeak);
    m      = mean(x);
    cohend = (m - baseline) / std(x);
    [~, ~, ci] = ttest(x, baseline);   % two-sided 95% CI, raw scale
    df     = st.df(iPeak);
    pPeak  = pFDR(iPeak);

    % if pPeak < 0.0001
    %     pstr = 'P < 0.0001';
    % elseif pPeak >= 0.0001 && pPeak < 0.001
    %     pstr = 'P < 0.001';
    % else
    if pPeak < 0.001   % APA: exact P to 3 decimals, "P < 0.001" below 0.001
        pstr = 'P < 0.001';
    else
        pstr = sprintf('P = %.3f', pPeak);
    end

    if strcmp(tail, 'both')
        tailstr = 'two-sided';
    else
        tailstr = 'one-sided';
    end

    % fprintf('%s (peak at trial %d):\n', label, iPeak);
    % fprintf('  mean = %.3f; 95%% CI, %.3f to %.3f; t%d = %.2f; %s %s (FDR-corrected); Cohen''s d = %.3f\n', ...
    %     m, ci(1), ci(2), df, tPeak, tailstr, pstr, cohend);
    % fprintf('  significant trials (FDR < 0.005): %s\n\n', mat2str(find(pFDR(:)' < 0.005)));
    if size(D, 2) > 1
        fprintf('%s (peak at trial %g):\n', label, trials(iPeak));
        corrstr = ' (FDR-corrected)';
    else
        fprintf('%s:\n', label);   % single measure: no trial, no correction
        corrstr = '';
    end
    fprintf('  mean = %.3f; 95%% CI, %.3f to %.3f; t%d = %.2f; %s %s%s; Cohen''s d = %.3f\n', ...
        m, ci(1), ci(2), df, tPeak, tailstr, pstr, corrstr, cohend);
    if size(D, 2) > 1
        fprintf('  significant trials (FDR < 0.005): %s\n\n', mat2str(trials(pFDR(:)' < 0.005)));
    else
        fprintf('\n');
    end
end