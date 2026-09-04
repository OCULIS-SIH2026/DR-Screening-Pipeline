function cfg = getConfig()
% GETCONFIG Returns unified configuration struct for the DR Screening Engine.
%
% Pulls values from the local .env file (if present) or environment variables,
% falling back to sensible project defaults.
%
% Usage:
%   cfg = getConfig();
%   modelPath = cfg.MODEL_PATH;
%   targetSize = cfg.TARGET_SIZE;

    % Load .env into MATLAB environment if not already loaded
    loadEnv();

    cfg = struct();

    % Paths & Directories
    cfg.DATASET_DIR   = getEnvVar('DATASET_DIR', 'datasets');
    cfg.MODEL_PATH    = getEnvVar('MODEL_PATH', 'model/weights/dr_screening_model.mat');
    cfg.OUTPUT_DIR    = getEnvVar('OUTPUT_DIR', 'reports');

    % Image Dimensions & Preprocessing
    targetH = str2double(getEnvVar('TARGET_IMAGE_HEIGHT', '224'));
    targetW = str2double(getEnvVar('TARGET_IMAGE_WIDTH', '224'));
    if isnan(targetH) || isnan(targetW)
        targetH = 224; targetW = 224;
    end
    cfg.TARGET_SIZE   = [targetH, targetW];

    % Quality Assessment Thresholds
    cfg.QUALITY_GOOD_THRESH       = str2double(getEnvVar('QUALITY_GOOD_THRESH', '0.75'));
    cfg.QUALITY_BORDERLINE_THRESH = str2double(getEnvVar('QUALITY_BORDERLINE_THRESH', '0.50'));
    cfg.SHARPNESS_MIN_THRESH      = str2double(getEnvVar('SHARPNESS_MIN_THRESH', '0.28'));

    % Enhancement Settings
    cfg.CLAHE_CLIP_LIMIT = str2double(getEnvVar('CLAHE_CLIP_LIMIT', '0.02'));
    cfg.DENOISE_METHOD   = getEnvVar('DENOISE_METHOD', 'bilateral');

    % Decision & Referral Logic
    cfg.REFERABLE_CUTOFF_CLASS    = str2double(getEnvVar('REFERABLE_CUTOFF_CLASS', '2')); % Level >= 2 is referable
    cfg.CONFIDENCE_MIN_ACCEPTABLE = str2double(getEnvVar('CONFIDENCE_MIN_ACCEPTABLE', '0.80'));
end

function val = getEnvVar(name, defaultVal)
    envVal = getenv(name);
    if isempty(envVal)
        val = defaultVal;
    else
        val = envVal;
    end
end
