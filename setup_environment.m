% SETUP_ENVIRONMENT
% Initializes the MATLAB environment for the Diabetic Retinopathy Screening Engine.
% Adds all required pipeline directories to the MATLAB search path.

function setup_environment()
    rootPath = fileparts(mfilename('fullpath'));
    
    subDirs = {
        'input', ...
        'quality', ...
        'enhancement', ...
        'anatomy', ...
        'lesions', ...
        'model', ...
        'explainability', ...
        'decision', ...
        'report', ...
        'simulink', ...
        'tests', ...
        'utils'
    };

    fprintf('====================================================\n');
    fprintf('  Initializing DR Screening Pipeline Environment...\n');
    fprintf('====================================================\n');

    for i = 1:numel(subDirs)
        dirPath = fullfile(rootPath, subDirs{i});
        if ~exist(dirPath, 'dir')
            mkdir(dirPath);
        end
        addpath(dirPath);
        fprintf('  [+] Added to path: %s\n', subDirs{i});
    end

    addpath(rootPath);
    fprintf('\nEnvironment successfully initialized.\n');
end
