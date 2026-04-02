function [f_kHz, magN] = oneSidedFFT(x, fs)
%ONESIDEDFFT Normalized one-sided FFT magnitude.

    x = double(x(:));
    x = x - mean(x, 'omitnan');
    n = numel(x);
    if n < 2
        f_kHz = 0;
        magN = 0;
        return;
    end

    X = fft(x);
    P2 = abs(X / n);
    P1 = P2(1:floor(n/2)+1);
    if numel(P1) > 2
        P1(2:end-1) = 2 * P1(2:end-1);
    end
    f = fs * (0:floor(n/2)) / n;

    magN = P1 ./ (max(P1) + eps);
    f_kHz = f(:) / 1e3;
end
