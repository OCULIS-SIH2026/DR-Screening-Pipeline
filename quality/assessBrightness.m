function [brightnessScore, metrics] = assessBrightness(img, retinaMask)
% ASSESSBRIGHTNESS Evaluates retinal illumination, exposure, and lighting uniformity.
%
% Usage:
%   [brightnessScore, metrics] = assessBrightness(img)
%   [brightnessScore, metrics] = assessBrightness(img, retinaMask)
%
% Inputs:
%   img        - RGB fundus image (uint8).
%   retinaMask - (Optional) Logical mask of the retinal area.
%
% Outputs:
%   brightnessScore - Normalized score in [0.0, 1.0].
%   metrics         - Struct containing:
%                       .meanIntensity
%                       .medianIntensity
%                       .underexposedRatio (fraction of retinal pixels < 20)
%                       .overexposedRatio  (fraction of retinal pixels > 240)
%                       .illuminationUniformity (sector consistency)
%                       .flags (cell array of warnings)
%
% Reference:
%   Phase 2: Image Quality Assessment

    if nargin < 2 || isempty(retinaMask)
        [~, ~, retinaMask] = assessFOV(img);
    end

    if ndims(img) == 3
        % Weighted luminance (Rec. 601)
        L = 0.299 * double(img(:,:,1)) + 0.587 * double(img(:,:,2)) + 0.114 * double(img(:,:,3));
    else
        L = double(img);
    end

    retinaPixels = L(retinaMask);
    totalRetinaPx = numel(retinaPixels);

    if totalRetinaPx == 0
        brightnessScore = 0.0;
        metrics = struct('meanIntensity', 0, 'underexposedRatio', 1.0, ...
                         'overexposedRatio', 0.0, 'brightnessScore', 0, 'flags', {{'EMPTY_MASK'}});
        return;
    end

    % 1. Core intensity measures
    meanInt = mean(retinaPixels);
    medInt  = median(retinaPixels);

    % 2. Exposure extremes
    underexposedPx = sum(retinaPixels < 25);
    overexposedPx  = sum(retinaPixels > 240);
    underRatio     = underexposedPx / totalRetinaPx;
    overRatio      = overexposedPx  / totalRetinaPx;

    % 3. Illumination uniformity (quadrant-based variance)
    [H, W] = size(L);
    midH = round(H / 2);
    midW = round(W / 2);
    quadMeans = zeros(1, 4);

    qMask1 = retinaMask; qMask1(midH:end, :) = false; qMask1(:, midW:end) = false;
    qMask2 = retinaMask; qMask2(midH:end, :) = false; qMask2(:, 1:midW)   = false;
    qMask3 = retinaMask; qMask3(1:midH, :)   = false; qMask3(:, midW:end) = false;
    qMask4 = retinaMask; qMask4(1:midH, :)   = false; qMask4(:, 1:midW)   = false;

    qMasks = {qMask1, qMask2, qMask3, qMask4};
    for q = 1:4
        m = qMasks{q};
        if any(m(:))
            quadMeans(q) = mean(L(m));
        else
            quadMeans(q) = meanInt;
        end
    end
    quadDev = std(quadMeans);
    uniformity = max(0.0, 1.0 - (quadDev / 40.0));

    % 4. Exposure score mapping
    % Optimal mean retinal luminance is typically between 70 and 150 (out of 255)
    if meanInt >= 70 && meanInt <= 150
        intensityScore = 1.0;
    elseif meanInt < 70
        % Drops as it gets darker
        intensityScore = max(0.0, meanInt / 70.0);
    else
        % Drops as it gets washed out
        intensityScore = max(0.0, 1.0 - ((meanInt - 150.0) / (255.0 - 150.0)));
    end

    % Extreme exposure penalties
    extremePenalty = 1.0;
    flags = {};

    if underRatio > 0.35
        extremePenalty = extremePenalty * max(0.1, 1.0 - 1.5 * underRatio);
        flags{end+1} = 'CRITICAL_UNDEREXPOSURE';
    elseif underRatio > 0.15
        flags{end+1} = 'MILD_UNDEREXPOSURE';
    end

    if overRatio > 0.20
        extremePenalty = extremePenalty * max(0.1, 1.0 - 2.0 * overRatio);
        flags{end+1} = 'CRITICAL_OVEREXPOSURE';
    elseif overRatio > 0.08
        flags{end+1} = 'MILD_OVEREXPOSURE';
    end

    if uniformity < 0.50
        flags{end+1} = 'UNEVEN_ILLUMINATION';
    end

    brightnessScore = min(1.0, max(0.0, (0.60 * intensityScore + 0.40 * uniformity) * extremePenalty));

    metrics = struct();
    metrics.meanIntensity          = meanInt;
    metrics.medianIntensity        = medInt;
    metrics.underexposedRatio      = underRatio;
    metrics.overexposedRatio       = overRatio;
    metrics.illuminationUniformity = uniformity;
    metrics.brightnessScore        = brightnessScore;
    metrics.flags                  = flags;
end
