function plotWaveform(ax, sig, fs, pickIdx, ttl)
%PLOTWAVEFORM Fast waveform preview with optional pick marker.

    cla(ax);
    sig = double(sig(:));
    t_us = (0:numel(sig)-1)' / fs * 1e6;
    plot(ax, t_us, sig, 'k-', 'LineWidth', 1.0);
    grid(ax, 'on');
    box(ax, 'on');
    xlabel(ax, 'Time (\mus)');
    ylabel(ax, 'Amplitude');
    title(ax, ttl, 'Interpreter', 'none');

    if nargin >= 4 && isfinite(pickIdx) && pickIdx >= 1 && pickIdx <= numel(sig)
        hold(ax, 'on');
        xline(ax, t_us(pickIdx), 'r--', 'LineWidth', 1.0);
        hold(ax, 'off');
    end
end
