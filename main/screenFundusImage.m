function sample = screenFundusImage(imageSource, model, varargin)
% SCREENFUNDUSIMAGE End-to-end master pipeline runner for fundus screening.
%
% Complete 9-Phase Automated Workflow:
%   [1] Ingest & format image        (loadFundusImage)
%   [2] Image Quality Assessment     (assessImageQuality)
%   [3] Selective Image Enhancement  (enhanceFundusImage)
%   [4] Retinal Structure Analysis   (analyzeRetinalStructures)
%   [5] Lesion Evidence Extraction   (detectLesionEvidence)
%   [6] CNN Forward Inference        (runDRModel)
%   [7] Grad-CAM Explainability      (generateGradCAM)
%   [8] Clinical Decision & Triage   (makeClinicalDecision)
%   [9] Automated Screening Report   (generateScreeningReport)
%
% Usage:
%   sample = screenFundusImage("patient_001.jpg")
%   sample = screenFundusImage("patient_001.jpg", model)
%   sample = screenFundusImage(rawImageMatrix, [], 'PatientID', "pt_42", 'SaveDir', 'reports')
%
% Inputs:
%   imageSource - File path string/char, or in-memory RGB image matrix.
%   model       - (Optional) Model struct from loadDRModel. If empty/omitted,
%                 automatically loads model from .env or calibrated mock.
%
% Name-Value Parameters:
%   'PatientID'  - String ID override.
%   'SaveDir'    - Directory to save reports (default: 'reports').
%   'ExportPNG'  - Logical. If true, saves dashboard image (default: true).
%   'ExportText' - Logical. If true, saves consultation note (default: true).
%   'TargetSize' - [H, W] input size for CNN (default: [224, 224]).
%
% Output:
%   sample      - Fully populated pipeline struct containing all 9 phase results.
%
% Reference:
%   Final Integration of DR Screening Implementation Plan

    p = inputParser;
    addRequired(p, 'imageSource');
    addOptional(p, 'model', []);
    addParameter(p, 'PatientID', "", @(x) ischar(x) || isstring(x));
    addParameter(p, 'SaveDir', "", @(x) ischar(x) || isstring(x));
    addParameter(p, 'ExportPNG', true, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'ExportText', true, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'TargetSize', [], @(x) isempty(x) || isnumeric(x));
    parse(p, imageSource, model, varargin{:});

    patientID = string(p.Results.PatientID);
    saveDir   = string(p.Results.SaveDir);
    exportPNG = logical(p.Results.ExportPNG);
    exportTxt = logical(p.Results.ExportText);
    targetSz  = p.Results.TargetSize;

    cfg = getConfig();
    if isempty(targetSz)
        targetSz = cfg.TARGET_SIZE;
    end
    if saveDir == ""
        saveDir = string(cfg.OUTPUT_DIR);
    end

    % 0. Load Model if not provided
    if isempty(model)
        model = loadDRModel();
    end

    % [Phase 1] Input Ingestion & Standardization
    sample = loadFundusImage(imageSource, 'TargetSize', targetSz, 'PatientID', patientID);

    % [Phase 2] Image Quality Assessment (IQA)
    sample = assessImageQuality(sample);

    % [Phase 3] Selective Enhancement (applied ONLY to BORDERLINE images)
    sample = enhanceFundusImage(sample);

    % [Phase 4] Retinal Structure Analysis (Optic Disc, Fovea, Vessels)
    sample = analyzeRetinalStructures(sample);

    % [Phase 5] Lesion Evidence Extraction (Microaneurysms, Hemorrhages, Exudates, NV)
    sample = detectLesionEvidence(sample);

    % [Phase 6] CNN Inference (5-class softmax probabilities)
    sample = runDRModel(model, sample);

    % [Phase 7] Explainability & Grad-CAM Heatmap
    sample = generateGradCAM(model, sample);

    % [Phase 8] Confidence Calibration & Clinical Decision Triage
    sample = makeClinicalDecision(sample);

    % [Phase 9] Automated Screening Report & Visual Dashboard
    sample = generateScreeningReport(sample, ...
        'SaveDir', char(saveDir), ...
        'ExportPNG', exportPNG, ...
        'ExportText', exportTxt);
end
