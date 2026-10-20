function T = sd_label(T, names, values)
% SD_LABEL  Prepend constant label columns to table T, e.g. sd_label(T, {'condition'}, {'match'}).
L = table();
for i = 1:numel(names)
    v = values{i};
    if ischar(v) || isstring(v)
        L.(names{i}) = repmat({char(v)}, height(T), 1);
    else
        L.(names{i}) = repmat(v, height(T), 1);
    end
end
T = [L, T];
end
