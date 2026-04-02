function D = readWaveFile(fileName, cfgIO)
%READWAVEFILE Unified wrapper around waveReader.
%
% Expected signature from your note:
% [t, wave, para, cumulativeEvents, eventTime, date, sf, numCh, numPara,
%  testTime, recordCount, headerLength, preTrigPoints] = waveReader(fileName)

    if nargin < 2
        cfgIO = struct();
    end

    [t, wave, para, cumulativeEvents, eventTime, dateStr, sf, numCh, ...
        numPara, testTime, recordCount, headerLength, preTrigPoints] = waveReader(fileName);

    D = struct();
    D.fileName = fileName;
    D.t = t;
    D.wave = wave;
    D.para = para;
    D.cumulativeEvents = cumulativeEvents;
    D.eventTime = eventTime(:);
    D.date = dateStr;
    D.fs = sf;
    D.numCh = numCh;
    D.numPara = numPara;
    D.testTime = testTime;
    D.recordCount = recordCount;
    D.headerLength = headerLength;
    D.preTrigPoints = preTrigPoints;

    if isfield(cfgIO, 'forceDouble') && cfgIO.forceDouble
        D.wave = double(D.wave);
    end

    D.nSamples = size(D.wave, 1);
    D.nEvents = size(D.wave, 3);
end
