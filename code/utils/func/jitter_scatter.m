function jitter_scatter(data, x, col, violin, sd, alpha, msz)
% Violin outline (default) plus scatter at position x, with horizontal jitter scaled by density.
    if nargin < 4, violin = true; end
    if nargin < 5, sd = 5;        end
    if nargin < 6, alpha = 0.04;   end
    if nargin < 7, msz = 20;      end

    data   = data(:);
    [f,xi] = ksdensity(data);
    f      = f ./ max(f);

    if violin
        w = 0.35;                                   % half-width of violin
        plot([x + w*f, fliplr(x - w*f), x + w*f(1)], [xi, fliplr(xi), xi(1)], ...
            'Color', col, 'LineWidth', 0.1);
        % plot(x - w*f, xi, 'Color', col, 'LineWidth', 0.3);
        hold on
    end

    ff  = interp1(xi, f, data, 'nearest', 'extrap');
    jit = randn(size(data)) .* ff / sd;
    scatter(x + jit, data, msz, col, 'filled', ...
        'MarkerFaceAlpha', alpha, 'MarkerEdgeAlpha', alpha);
    hold on
end