function E = buildEventTable(D)
%BUILDEVENTTABLE Create a clean base event table.

    nEv = D.nEvents;
    E = table((1:nEv)', 'VariableNames', {'eventID'});

    if ~isempty(D.eventTime) && numel(D.eventTime) == nEv
        E.hittime_s = D.eventTime(:);
    else
        E.hittime_s = nan(nEv,1);
    end

    E.k0_samp = ones(nEv,1);
    E.kEnd_samp = D.nSamples * ones(nEv,1);
    E.win_us = (E.kEnd_samp - E.k0_samp + 1) / D.fs * 1e6;
end
