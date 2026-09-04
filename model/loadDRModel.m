function modelWrapper = loadDRModel(modelPath, varargin)
% LOADDRMODEL Loads a trained Diabetic Retinopathy CNN model or calibrated mock.
%
% Supported Formats:
%   - MATLAB .mat files containing DAGNetwork, SeriesNetwork, or dlnetwork
%   - ONNX models (.onnx via importONNXNetwork)
%   - Calibrated mock model (used automatically if weights are not yet placed)
%
% Usage:
%   model = loadDRModel()                 % Uses path from .env or loads mock
%   model = loadDRModel("weights.mat")    % Loads specific .mat file
%   model = loadDRModel("mock")           % Explicitly creates mock model
%
% Outputs:
%   modelWrapper - Standard struct wrapping the network, contract, and metadata.
%
% Reference:
%   Phase 6: CNN Inference Integration

    cfg = getConfig();

    if nargin < 1 || isempty(modelPath) || modelPath == ""
        modelPath = cfg.MODEL_PATH;
    end
    modelPath = string(modelPath);

    modelWrapper = struct();
    contract = getModelContract();

    % 1. Handle explicit "mock" or non-existent file request
    if lower(modelPath) == "mock" || ~exist(modelPath, 'file')
        if lower(modelPath) ~= "mock"
            fprintf('Notice: Model weights not found at "%s". Using calibrated mock model.\n', modelPath);
        end
        modelWrapper = createMockDRModel('Contract', contract);
        modelWrapper.filePath = modelPath;
        return;
    end

    % 2. Load from existing file
    [~, ~, ext] = fileparts(char(modelPath));

    switch lower(ext)
        case '.mat'
            try
                matData = load(modelPath);
                fields = fieldnames(matData);
                
                % Find network variable in MAT-file
                netObj = [];
                for i = 1:numel(fields)
                    val = matData.(fields{i});
                    if isstruct(val) && isfield(val, 'isMock') && val.isMock
                        modelWrapper = val;
                        modelWrapper.filePath = modelPath;
                        return;
                    elseif isa(val, 'DAGNetwork') || isa(val, 'SeriesNetwork') || ...
                           isa(val, 'dlnetwork')
                        netObj = val;
                        break;
                    end
                end

                if isempty(netObj)
                    % If no recognized network class, use first variable or fallback to mock
                    warning('loadDRModel:NoNetworkFound', ...
                        'No recognized network object in "%s". Falling back to calibrated mock.', modelPath);
                    modelWrapper = createMockDRModel('Contract', contract);
                    modelWrapper.filePath = modelPath;
                    return;
                end

                modelWrapper.net          = netObj;
                modelWrapper.isMock       = false;
                modelWrapper.name         = string(fields{1});
                modelWrapper.contract     = contract;
                modelWrapper.filePath     = modelPath;
                modelWrapper.classes      = contract.classes.labels;
                modelWrapper.gradCAMLayer = contract.gradCAMLayer;
                fprintf('Successfully loaded CNN model: %s (%s)\n', modelWrapper.name, class(netObj));

            catch ME
                warning('loadDRModel:LoadFailed', 'Failed to load "%s": %s. Using mock.', modelPath, ME.message);
                modelWrapper = createMockDRModel('Contract', contract);
                modelWrapper.filePath = modelPath;
            end

        case '.onnx'
            try
                if exist('importONNXNetwork', 'file') == 2
                    netObj = importONNXNetwork(char(modelPath), 'OutputDataFormats', 'BC');
                    modelWrapper.net          = netObj;
                    modelWrapper.isMock       = false;
                    modelWrapper.name         = "ONNX_DR_Model";
                    modelWrapper.contract     = contract;
                    modelWrapper.filePath     = modelPath;
                    modelWrapper.classes      = contract.classes.labels;
                    modelWrapper.gradCAMLayer = contract.gradCAMLayer;
                    fprintf('Successfully imported ONNX CNN model from: %s\n', modelPath);
                else
                    warning('loadDRModel:ONNXNotSupported', ...
                        'Deep Learning Toolbox Converter for ONNX not installed. Using mock.');
                    modelWrapper = createMockDRModel('Contract', contract);
                    modelWrapper.filePath = modelPath;
                end
            catch ME
                warning('loadDRModel:ONNXFailed', 'ONNX import failed: %s. Using mock.', ME.message);
                modelWrapper = createMockDRModel('Contract', contract);
                modelWrapper.filePath = modelPath;
            end

        otherwise
            error('loadDRModel:UnsupportedFormat', 'Unsupported model format "%s". Use .mat or .onnx', ext);
    end
end
