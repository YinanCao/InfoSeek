function T = sd_ttest(T, D, mu, tail, qthr)
% SD_TTEST  Add per-column t-tests across participants (rows of D) to table T:
%   t, df, exact P and q_FDR (Benjamini-Hochberg adjusted P across the columns).
%   If qthr is given, also add thick_line = 1 where q_FDR < qthr (as drawn in the figure).
[~, p, ~, st] = ttest(D, mu, 'Tail', tail);
q = mafdr(p(:), 'BHFDR', true);
T.t     = st.tstat(:);
T.df    = st.df(:);
T.P     = p(:);
T.q_FDR = q(:);
if nargin > 4
    T.thick_line = double(q(:) < qthr);
end
end
