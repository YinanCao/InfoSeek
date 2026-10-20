function sd_readback(file, chk)
% SD_READBACK  Re-read every sheet listed in chk and compare the sum of its numeric
%   cells with the sums recorded by sd_block. Numbers written as text may be read
%   back either as text or as numbers, so both totals are accepted.
sheets = fieldnames(chk);
for i = 1:numel(sheets)
    s   = chk.(sheets{i});
    if numel(s) < 2, s(2) = 0; end
    C   = readcell(file, 'Sheet', sheets{i});
    isn = cellfun(@(v) isnumeric(v) && isscalar(v) && ~isnan(v), C);
    got = sum(cell2mat(C(isn)));
    tol = 1e-6 * max(1, abs(s(1)) + abs(s(2)));
    assert(abs(got - s(1)) <= tol || abs(got - s(1) - s(2)) <= tol, ...
        'Read-back mismatch in sheet %s', sheets{i});
end
fprintf('Source Data written and checked: %s\n', file);
end
