function plotCWTModal(ax, sig, fs, pickIdx, C, ttl)
%PLOTCWTMODAL Phase-1 CWT view with the same drawing logic family as the
% user's Matlab-MAE-CWT-DC plotting routine, without dispersion overlay.

    try
        M = hexvis.vis.computeCWTMap(sig, fs, C);
        hexvis.vis.drawTFMap(ax, M, pickIdx, ttl, [0 1], C, C.showColorbar);
    catch ME
        cla(ax);
        text(ax, 0.5, 0.5, sprintf('CWT failed:\n%s', ME.message), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
        axis(ax, 'off');
    end
end
