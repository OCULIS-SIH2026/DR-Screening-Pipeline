function [outSample, enhancedImg, info] = enhanceFundusImage(inputArg, varargin)
% ENHANCEFUNDUSIMAGE Master enhancement and normalization pipeline for fundus images.
%
% Strictly adheres to clinical protocol:
%   - "GOOD"       --> Preserve original to avoid creating artifactual lesions.
%   - "BORDERLINE" --> Apply illumination correction, CLAHE, and edge-preserving denoising.
%   - "RECAPTURE"  --> Do not attempt aggressive rescue (flagged for technician recapture).
%   - Force=true   --> Overrides quality gate (useful for offline experimentation).
%
% Usage:
%   sample = enhanceFundusImage(sample)
%   sample = enhanceFundusImage(sample, 'Force', true)
%   [sample, enhancedImg, info] = enhanceFundusImage(sample)
%   [enhancedImg, info] = enhanceFundusImage(rawImageMatrix)
%
% Name-Value Parameters:
%   'Force'      - Logical. If true, bypasses quality gate and enhances regardless of status.
%   'ClipLimit'  - Contrast clipping limit for CLAHE (default: 0.02).
%   'Sigma'      - Illumination filter scale (default: auto ~10% of width).
%   'Denoise'    - 'bilateral', 'median3x3', or 'none' (default: 'bilateral').
%
% Outputs:
%   outSample   - Updated sample struct with sample.enhancedImage and sample.enhancementInfo.
%   enhancedImg - Enhanced RGB image matrix (uint8).
%   info        - Struct with enhancement parameters and execution status.
%
% Reference:
%   Phase 3: Image Enhancement and Normalization

    p = inputParser;
    p.CaseSensitive = false;
    addRequired(p, 'inputArg');
    addParameter(p, 'Force', false, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'ClipLimit', 0.02, @(x) isnumeric(x) && x > 0 && x <= 1);
    addParameter(p, 'Sigma', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
    addParameter(p, 'Denoise', 'bilateral', @(x) ischar(x) || isstring(x));
    parse(p, inputArg, varargin{:});

    forceEnhance = logical(p.Results.Force);
    clipLimit    = p.Results.ClipLimit;
    sigma        = p.Results.Sigma;
    denoiseMode  = char(p.Results.Denoise);

    isSampleStruct = isstruct(inputArg) && isfield(inputArg, 'image');

    if isSampleStruct
        sample = inputArg;
        img = sample.image;
        % Check if Phase 2 quality assessment has been run
        if isempty(sample.quality) || sample.quality.status == ""
            sample = assessImageQuality(sample);
        end
        qualityStatus = sample.quality.status;
        retinaMask = sample.quality.retinaMask;
    elseif isstring(inputArg) || ischar(inputArg)
        sample = loadFundusImage(inputArg);
        sample = assessImageQuality(sample);
        img = sample.image;
        qualityStatus = sample.quality.status;
        retinaMask = sample.quality.retinaMask;
        isSampleStruct = true;
    elseif isnumeric(inputArg) || islogical(inputArg)
        img = inputArg;
        sample = [];
        [qualityStatus, ~, ~] = assessImageQuality(img);
        [~, ~, retinaMask] = assessFOV(img);
    else
        error('enhanceFundusImage:InvalidInput', 'Input must be a sample struct, image matrix, or file path.');
    end

    info = struct();
    info.applied    = false;
    info.method     = "none";
    info.reason     = "";
    info.parameters = struct('clipLimit', clipLimit, 'sigma', sigma, 'denoise', denoiseMode);

    % Decision Gate: Should we enhance this image?
    if ~forceEnhance && qualityStatus == "GOOD"
        % Rule: GOOD images preserve original to prevent artificial lesion generation
        enhancedImg = img;
        info.applied = false;
        info.method  = "pass_through_original";
        info.reason  = "Image quality is GOOD. Preserved original to avoid artificial lesion artifacts.";
    elseif ~forceEnhance && qualityStatus == "RECAPTURE"
        % Rule: RECAPTURE images are not aggressively enhanced (must be retaken)
        enhancedImg = img;
        info.applied = false;
        info.method  = "rejected_recapture";
        info.reason  = "Image quality is RECAPTURE. Aggressive enhancement avoided; retake recommended.";
    else
        % Condition: BORDERLINE quality OR Force == true
        % Execute Full 4-Step Enhancement Pipeline:
        
        % Step 1: Illumination Normalization
        [step1Img, illumMap] = normalizeIllumination(img, retinaMask, 'Sigma', sigma);

        % Step 2: CLAHE in CIE L*a*b* space
        step2Img = applyCLAHE(step1Img, retinaMask, 'ClipLimit', clipLimit, 'Distribution', 'rayleigh');

        % Step 3: Edge-Preserving Denoising
        if ~strcmpi(denoiseMode, 'none')
            step3Img = denoiseFundus(step2Img, retinaMask, 'Method', denoiseMode);
        else
            step3Img = step2Img;
        end

        enhancedImg = step3Img;
        info.applied = true;
        info.method  = "IlluminationNorm + CLAHE_Lab + " + string(denoiseMode);
        if forceEnhance
            info.reason = "Enhancement forced by user parameter.";
        else
            info.reason = "Applied to BORDERLINE image to improve vessel and lesion visibility.";
        end
        info.parameters.illuminationEstimated = ~isempty(illumMap);
    end

    % Update sample struct
    if isSampleStruct
        sample.enhancedImage   = enhancedImg;
        sample.enhancementInfo = info;
        outSample = sample;
    else
        outSample = enhancedImg;
    end
end
