function startup_hexvis()
%STARTUP_HEXVIS Add V1.01 and V1.0 fallback folders to MATLAB path.

    root101 = fileparts(mfilename('fullpath'));
    addpath(root101);
    addpath(genpath(fullfile(root101, '+hexvis')));

    root10 = fullfile(fileparts(root101), 'HexVisuTool_V1.0');
    if exist(root10, 'dir')
        addpath(root10);
        addpath(genpath(fullfile(root10, '+hexvis')));
    end
end
