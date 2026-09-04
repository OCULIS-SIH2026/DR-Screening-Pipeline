function [contrastScore, metrics] = assessContrast(img, retinaMask)
% ASSESSCONTRAST Evaluates retinal contrast and structural visibility.
%
% Usage:
%   [contrastScore, metrics] = assessContrast(img)
%   [contrastScore, metrics] = assessContrast(img, retinaMask)
%
% Inputs:
%   img        - RGB fundus image (uint8).
%   retinaMask - (Optional) Logical mask of the retinal area.
%
% Outputs:
%   contrastScore - Normalized score in [0.0, 1.0].
%   metrics       - Struct containing:
%                     .rmsContrast (std / mean in retina)
%                     .dynamicRange90 (p95 - p05)
%                     .michelsonContrast
%
% Reference:
%   Phase 2: Image Quality Assessment

    if nargin < 2 || isempty(retinaMask)
        [~, ~, retinaMask] = assessFOV(img);
    end

    % Green channel provides maximum optical absorption contrast in fundus images
    if ndims(img) == 3
        channel = double(img(:, :, 2));
    else
        channel = double(img);
    end

    retinaPixels = channel(retinaMask);
    if isempty(retinaPixels)
        contrastScore = 0.0;
        metrics = struct('rmsContrast', 0, 'dynamicRange90', 0, 'michelsonContrast', 0, 'contrastScore', 0);
        return;
    end

    % 1. RMS Contrast
    mu = mean(retinaPixels);
    sigma = std(retinaPixels);
    if mu > 0
        rmsContrast = sigma / mu;
    else
        rmsContrast = 0;
    end

    % 2. 90% Dynamic Range (p95 - p05)
    p05 = prctile(retinaPixels, 5);
    p95 = prctile(retinaPixels, 95);
    dynamicRange = p95 - p05;

    % 3. Michelson Contrast
    if (p95 + p05) > 0
        michelson = (p95 - p05) / (p95 + p05);
    else
        michelson = 0;
    end

    % 4. Normalization to [0, 1]
    % Typical good fundus green channel has dynamicRange in [50, 130] and rmsContrast > 0.20
    rangeScore = min(1.0, max(0.0, (dynamicRange - 20) / (85 - 20)));
    rmsScore   = min(1.0, max(0.0, (rmsContrast - 0.10) / (0.35 - 0.10)));

    contrastScore = min(1.0, max(0.0, 0.60 * rangeScore + 0.40 * rmsScore));

    metrics = struct();
    metrics.rmsContrast       = rmsContrast;
    metrics.dynamicRange90    = dynamicRange;
    metrics.michelsonContrast = michelson;
    metrics.contrastScore     = contrastScore;
end
