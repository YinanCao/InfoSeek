% SETUP_PATHS  Add the InfoSeek code and data folders to the MATLAB path.
%
%   Run once per MATLAB session, from any folder:
%       run('/path/to/InfoSeek/setup_paths.m')
%   Afterwards, every script in code/figures can be run by name
%   (for example: fig2) from any working folder.
%
%   The BADS and VBMC toolboxes (code/utils/toolbox) are not added here.
%   The model-fitting scripts in code/model add them when they run.

root = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(root, 'code', 'utils', 'func')));
addpath(fullfile(root, 'code', 'model'));
addpath(fullfile(root, 'code', 'figures'));
addpath(fullfile(root, 'data', 'derived'));

% Warn if another copy of the data on the path shadows this repository's.
datafile = which('dat_choicestbl_COLINE.mat');
if ~startsWith(datafile, root)
    warning('setup_paths:shadowed', ...
        'dat_choicestbl_COLINE.mat resolves to "%s", not to this repository.', datafile);
end
clear root datafile
