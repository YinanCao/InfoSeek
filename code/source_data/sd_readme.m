function sd_readme(file, lines)
% SD_README  Write the README sheet (one line per row in column A).
writecell(lines(:), file, 'Sheet', 'README', 'Range', 'A1');
end
