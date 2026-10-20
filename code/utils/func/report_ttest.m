function report_ttest(x, baseline, label)
% REPORT_TTEST  Two-sided one-sample t-test against a baseline.
% Mean and 95% CI are on the raw scale of x.
% t, P and Cohen's d are based on the difference from baseline.

    [~, p, ci, st] = ttest(x, baseline);
    m      = mean(x);
    cohend = (m - baseline) / std(x);

    % if p < 0.0001
    %     pstr = 'P < 0.0001';
    % elseif p >= 0.0001 && p < 0.001
    %     pstr = 'P < 0.001';
    % else
    if p < 0.001   % APA: exact P to 3 decimals, "P < 0.001" below 0.001
        pstr = 'P < 0.001';
    else
        pstr = sprintf('P = %.3f', p);
    end

    fprintf('%s:\n', label);
    fprintf('  mean = %.3f; 95%% CI, %.3f to %.3f; t%d = %.2f; two-sided %s; Cohen''s d = %.3f\n\n', ...
        m, ci(1), ci(2), st.df, st.tstat, pstr, cohend);
end