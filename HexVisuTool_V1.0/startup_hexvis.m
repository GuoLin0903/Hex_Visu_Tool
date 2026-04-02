function startup_hexvis()
%STARTUP_HEXVIS Add current project folder to MATLAB path.
%
% Put this folder next to your existing dependency files, or copy these
% files into your existing HEX_VISU_widget root. This function only adds the
% current project root and its package folders to path.

    here = fileparts(mfilename('fullpath'));
    addpath(here);

    % Package folders under +hexvis do not need genpath individually once the
    % project root is on path, but adding subfolders that are NOT package
    % folders remains useful if you later add local helpers.
    aux = {'private', 'deps'};
    for k = 1:numel(aux)
        p = fullfile(here, aux{k});
        if exist(p, 'dir') == 7
            addpath(genpath(p));
        end
    end
end
