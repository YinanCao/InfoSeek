function c = sd_names(fmt, vals)
% SD_NAMES  Column names from a format string, one per column of vals.
c = arrayfun(@(k) sprintf(fmt, vals(:, k)), 1:size(vals, 2), 'UniformOutput', false);
end
