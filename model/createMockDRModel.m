function mockModel = createMockDRModel(varargin)
% CREATEMOCKDRMODEL Creates a calibrated mock CNN model for testing without external weights.
%
% Enables full pipeline verification, Grad-CAM generation, and report building
% before the external CNN teammate provides the final trained .mat / ONNX weights.
%
% Usage:
%   mockModel = createMockDRModel()
%   mockModel = createMockDRModel('SaveToFile', 'model/weights/mock_dr_model.mat')
%
% Reference:
%   Phase 6: CNN Inference Integration

    p = inputParser;
    addParameter(p, 'SaveToFile', "", @(x) isstring(x) || ischar(x));
    addParameter(p, 'Contract', [], @(x) isempty(x) || isstruct(x));
    parse(p, varargin{:});

    filePath = string(p.Results.SaveToFile);
    contract = p.Results.Contract;
    if isempty(contract)
        contract = getModelContract();
    end

    mockModel = struct();
    mockModel.isMock       = true;
    mockModel.name         = "Calibrated_Mock_ResNet50_DR";
    mockModel.contract     = contract;
    mockModel.architecture = "ResNet-50 Fine-Tuned on APTOS-2019";
    mockModel.numClasses   = 5;
    mockModel.classes      = contract.classes.labels;
    mockModel.gradCAMLayer = contract.gradCAMLayer;
    mockModel.version      = "1.0.0-prototype";

    % Save to disk if requested
    if filePath ~= ""
        saveDir = fileparts(filePath);
        if saveDir ~= "" && ~exist(saveDir, 'dir')
            mkdir(saveDir);
        end
        save(filePath, 'mockModel');
        fprintf('Saved mock model weights to: %s\n', filePath);
    end
end
