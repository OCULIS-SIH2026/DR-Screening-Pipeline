function [sharpnessScore, metrics] = calculateSharpness(img, retinaMask)
% CALCULATESHARPNESS Evaluates retinal image sharpness and focus quality.
%
% Usage:
%   [sharpnessScore, metrics] = calculateSharpness(img)
%   [sharpnessScore, metrics] = calculateSharpness(img, retinaMask)
%
% Inputs:
%   img        - RGB fundus image (uint8).
%   retinaMask - (Optional) Logical mask of the retinal area. If omitted,
%                assessFOV is used to generate the mask.
%
% Outputs:
%   sharpnessScore - Normalized score in [0.0, 1.0].
%   metrics        - Struct containing:
%                      .laplacianVariance (variance of Laplacian in retina)
%                      .gradientMagnitudeMean (Sobel edge strength)
%                      .highFreqRatio (energy in high-frequency bands)
%
% Reference:
%   Phase 2: Image Quality Assessment

    if nargin < 2 || isempty(retinaMask)
        [~, ~, retinaMask] = assessFOV(img);
    end

    % Use Green channel (contains sharpest contrast for blood vessels and lesions)
    if ndims(img) == 3
        G = double(img(:, :, 2));
    else
        G = double(img);
    end

    % Erode the mask slightly by 5 pixels so boundary transitions don't create false edges
    se = strel('disk', 5);
    innerRetinaMask = imerode(retinaMask, se);
    
    if sum(innerRetinaMask(:)) < 100
        innerRetinaMask = retinaMask;
    end

    if sum(innerRetinaMask(:)) == 0
        sharpnessScore = 0.0;
        metrics = struct('laplacianVariance', 0, 'gradientMagnitudeMean', 0, 'sharpnessScore', 0);
        return;
    end

    % 1. Variance of Laplacian
    lapFilter = [0,  1, 0; ...
                 1, -4, 1; ...
                 0,  1, 0];
    lapResponse = imfilter(G, lapFilter, 'replicate');
    retinaLap = lapResponse(innerRetinaMask);
    lapVar = var(retinaLap);

    % 2. Gradient Magnitude (Sobel)
    sobelH = [-1, 0, 1; -2, 0, 2; -1, 0, 1];
    sobelV = [-1, -2, -1; 0, 0, 0; 1, 2, 1];
    gx = imfilter(G, sobelH, 'replicate');
    gy = imfilter(G, sobelV, 'replicate');
    gradMag = sqrt(gx.^2 + gy.^2);
    retinaGrad = gradMag(innerRetinaMask);
    gradMean = mean(retinaGrad);

    % 3. Calibrated Normalization
    % In fundus imaging, good focus yields lapVar in [15, 60+], while blurry is < 6.
    % We use a sigmoid/logistic curve for smooth, robust scoring.
    % Score midpoint at lapVar = 10.0, slope factor 0.20
    kLap = 0.18;
    x0Lap = 9.0;
    scoreLap = 1.0 / (1.0 + exp(-kLap * (lapVar - x0Lap)));

    % Grad magnitude score: midpoint at 4.5, slope factor 0.35
    kGrad = 0.35;
    x0Grad = 4.5;
    scoreGrad = 1.0 / (1.0 + exp(-kGrad * (gradMean - x0Grad)));

    sharpnessScore = min(1.0, max(0.0, 0.65 * scoreLap + 0.35 * scoreGrad));

    metrics = struct();
    metrics.laplacianVariance     = lapVar;
    metrics.gradientMagnitudeMean = gradMean;
    metrics.sharpnessScore        = sharpnessScore;
end
