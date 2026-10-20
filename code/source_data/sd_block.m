function [r, s] = sd_block(file, sheet, r, title, T, s)
% SD_BLOCK  Write a title line and table T to a sheet, starting at row r.
%   Returns the next free row and running sums used by sd_readback to check the
%   file: s(1) = sum of all numeric values written, s(2) = sum of numbers written
%   as text (for example P values such as '0.234').
if numel(s) < 2, s(2) = 0; end
writecell({title}, file, 'Sheet', sheet, 'Range', sprintf('A%d', r));
writetable(T, file, 'Sheet', sheet, 'Range', sprintf('A%d', r + 1));
for v = 1:width(T)
    x = T.(v);
    if isnumeric(x) || islogical(x)
        x = double(x);
        s(1) = s(1) + sum(x(~isnan(x)), 'all');
    elseif iscellstr(x) || isstring(x)
        y = str2double(x);
        s(2) = s(2) + sum(y(~isnan(y)), 'all');
    end
end
r = r + height(T) + 4;   % title + header + rows + 2 blank rows
end
