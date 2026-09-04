function [outSample, status, overallScore, detailedMetrics] = assessImageQuality(inputArg, varargin)
% ASSESSIMAGEQUALITY Main quality assessment engine for fundus screening.
%
% Determines whether a fundus image is of sufficient clinical quality for
% automated DR classification and feature extraction.
%
% Usage:
%   sample = assessImageQuality(sample)
%   [sample, status, overallScore, metrics] = assessImageQuality(sample)
%   [status, overallScore, metrics] = assessImageQuality(rawImage)
%
% Inputs:
%   inputArg - Standard sample struct (from loadFundusImage), raw image matrix,
%              or file path string.
%
% Outputs:
%   outSample       - Updated sample struct with sample.quality populated.
%   status          - "GOOD", "BORDERLINE", or "RECAPTURE".
%   overallScore    - Composite quality score in [0.0, 1.0].
%   detailedMetrics - Struct containing sub-scores and component measurements.
%
% Quality Tiers:
%   Score >= 0.75 & no hard fail  --> "GOOD"
%   0.50 <= Score < 0.75          --> "BORDERLINE" (enhancement candidate)
%   Score < 0.50 OR hard fail     --> "RECAPTURE"  (unusable)
%
% Reference:
%   Phase 2: Image Quality Assessment

    isSampleStruct = isstruct(inputArg) && isfield(inputArg, 'image');

    if isSampleStruct
        sample = inputArg;
        img = sample.image;
        if isempty(img)
            error('assessImageQuality:EmptyImage', 'sample.image is empty.');
        end
    elseif isstring(inputArg) || ischar(inputArg)
        sample = loadFundusImage(inputArg);
        img = sample.image;
        isSampleStruct = true;
    elseif isnumeric(inputArg) || islogical(inputArg)
        img = inputArg;
        sample = [];
    else
        error('assessImageQuality:InvalidInput', 'Input must be a sample struct, image matrix, or file path.');
    end

    % 1. Step 1: Retinal Field of View & Foreground Mask
    [fovScore, fovMetrics, retinaMask] = assessFOV(img);

    % 2. Step 2: Focus & Sharpness (inside retina mask)
    [sharpnessScore, sharpnessMetrics] = calculateSharpness(img, retinaMask);

    % 3. Step 3: Brightness & Illumination
    [brightnessScore, brightnessMetrics] = assessBrightness(img, retinaMask);

    % 4. Step 4: Contrast & Structural Definition
    [contrastScore, contrastMetrics] = assessContrast(img, retinaMask);

    % 5. Composite Overall Score (Weighted combination)
    % Sharpness is the most critical for microaneurysms and fine vessel detection (35%)
    wSharpness  = 0.35;
    wBrightness = 0.25;
    wContrast   = 0.20;
    wFOV        = 0.20;

    overallScore = (wSharpness * sharpnessScore) + ...
                   (wBrightness * brightnessScore) + ...
                   (wContrast * contrastScore) + ...
                   (wFOV * fovScore);
    overallScore = min(1.0, max(0.0, overallScore));

    % 6. Clinical Hard Rejection Rules & Reason Logging
    rejectionReasons = {};
    hardFail = false;

    if sharpnessScore < 0.28
        hardFail = true;
        rejectionReasons{end+1} = sprintf('Severe blur/defocus detected (Sharpness: %.2f)', sharpnessScore);
    end

    if fovMetrics.retinalAreaRatio < 0.25
        hardFail = true;
        rejectionReasons{end+1} = sprintf('Retinal field heavily clipped or missed (FOV coverage: %.1f%%)', ...
            fovMetrics.retinalAreaRatio * 100);
    end

    if brightnessMetrics.underexposedRatio > 0.45
        hardFail = true;
        rejectionReasons{end+1} = sprintf('Severe underexposure / dark image (%.1f%% underexposed pixels)', ...
            brightnessMetrics.underexposedRatio * 100);
    end

    if brightnessMetrics.overexposedRatio > 0.30
        hardFail = true;
        rejectionReasons{end+1} = sprintf('Severe overexposure / flash flare (%.1f%% saturated pixels)', ...
            brightnessMetrics.overexposedRatio * 100);
    end

    % 7. Determine Final Quality Classification
    if hardFail || overallScore < 0.50
        status = "RECAPTURE";
        if isempty(rejectionReasons)
            rejectionReasons{end+1} = sprintf('Overall quality score (%.2f) below acceptable screening threshold (0.50)', overallScore);
        end
    elseif overallScore >= 0.75
        status = "GOOD";
    else
        status = "BORDERLINE";
        if sharpnessScore < 0.50
            rejectionReasons{end+1} = 'Moderate blur; may impair microaneurysm detection';
        end
        if contrastScore < 0.50
            rejectionReasons{end+1} = 'Low structural contrast; candidate for CLAHE enhancement';
        end
        if brightnessScore < 0.60
            rejectionReasons{end+1} = 'Suboptimal exposure; candidate for illumination normalization';
        end
    end

    % 8. Package metrics
    detailedMetrics = struct();
    detailedMetrics.overallScore     = overallScore;
    detailedMetrics.sharpnessScore   = sharpnessScore;
    detailedMetrics.brightnessScore  = brightnessScore;
    detailedMetrics.contrastScore    = contrastScore;
    detailedMetrics.fovScore         = fovScore;
    detailedMetrics.hardFail         = hardFail;
    detailedMetrics.rejectionReasons = rejectionReasons;
    detailedMetrics.fov              = fovMetrics;
    detailedMetrics.sharpness        = sharpnessMetrics;
    detailedMetrics.brightness       = brightnessMetrics;
    detailedMetrics.contrast         = contrastMetrics;

    % 9. Update sample struct if applicable
    if isSampleStruct
        sample.quality.status           = status;
        sample.quality.overallScore     = overallScore;
        sample.quality.sharpness        = sharpnessScore;
        sample.quality.brightness       = brightnessScore;
        sample.quality.contrast         = contrastScore;
        sample.quality.fov              = fovScore;
        sample.quality.rejectionReasons = rejectionReasons;
        sample.quality.retinaMask       = retinaMask;
        sample.quality.metrics          = detailedMetrics;
        outSample = sample;
    else
        outSample = status; % For backward compatibility when called with raw matrix
    end
end
