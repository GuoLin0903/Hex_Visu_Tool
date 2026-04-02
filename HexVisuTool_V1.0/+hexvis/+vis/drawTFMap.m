function drawTFMap(ax, M, pickIdx, ttl, clim, cfgCWT, showColorbar)
%DRAWTFMAP Draw a precomputed TF map.

    if nargin < 7, showColorbar = false; end
    if nargin < 6 || isempty(cfgCWT), cfgCWT = struct(); end
    if nargin < 5 || isempty(clim), clim = [0 1]; end

    cla(ax);
    if isempty(M) || isempty(M.A_show)
        text(ax, 0.5, 0.5, 'Empty TF map', 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle');
        axis(ax, 'off');
        return;
    end

    imagesc(ax, M.t_us, M.f_kHz, M.A_show);
    axis(ax, 'xy');
    xlim(ax, [0, M.t_us(end)]);
    ylim(ax, [0, max(M.f_kHz)]);
    caxis(ax, clim);
    xlabel(ax, 'Time [\mus]');
    ylabel(ax, 'Freq [kHz]');
    title(ax, ttl, 'Interpreter', 'none');
    box(ax, 'on');
    grid(ax, 'on');

    if isfield(cfgCWT, 'colormapName') && strcmpi(cfgCWT.colormapName, 'jet')
        colormap(ax, jet(256));
    elseif exist('turbo', 'file') ~= 0
        colormap(ax, turbo);
    else
        colormap(ax, parula);
    end

    if nargin >= 3 && isfinite(pickIdx) && pickIdx >= 1
        hold(ax, 'on');
        if pickIdx <= numel(M.t_us)
            xline(ax, M.t_us(pickIdx), 'w--', 'LineWidth', 1.0);
        end
        hold(ax, 'off');
    end

    if showColorbar
        colorbar(ax);
    end
end
