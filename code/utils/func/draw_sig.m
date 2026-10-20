function draw_sig(qvals, ypos, siglw, chancecolor)

    gap_threshold = 1.1;
    gap_idx = find(diff(qvals) > gap_threshold);
    yvals = qvals * 0 + ypos;
    % Add start and end indices for segmentation
    segment_starts = [1, gap_idx + 1];
    segment_ends   = [gap_idx, length(qvals)];
    hold on
    for i = 1:length(segment_starts)
        idx_range = segment_starts(i):segment_ends(i);
        plot(qvals(idx_range), yvals(idx_range), '-', 'linewidth', siglw, 'color', chancecolor);
    end

end