function [normImg, illumMap] = normalizeIllumination(img, retinaMask, varargin)
% NORMALIZEILLUMINATION Corrects non-uniform illumination and vignetting in fundus images.
%
% Usage:
%   normImg = normalizeIllumination(img)
%   [normImg, illumMap] = normalizeIllumination(img, retinaMask)
%   [normImg, illumMap] = normalizeIllumination(img, retinaMask, 'Sigma', 35)
%
% Inputs:
%   img        - RGB fundus image (uint8).
%   retinaMask - (Optional) Logical mask of the retinal area. If omitted,
%                assessFOV is used to generate the mask.
%
% Name-Value Parameters:
%   'Sigma'    - Spatial filter scale for background field estimation (default: ~10% of image size).
%
% Outputs:
%   normImg    - Illumination-corrected RGB image (uint8).
%   illumMap   - Estimated 2D background illumination field.
%
% Reference:
%   Phase 3 of DR_Screening_10_Phase_Implementation_Plan.md

    p = inputParser;
    addRequired(p, 'img');
    addOptional(p, 'retinaMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
    addParameter(p, 'Sigma', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
    parse(p, img, retinaMask, varargin{:});

    mask = p.Results.retinaMask;
    if isempty(mask)
        [~, ~, mask] = assessFOV(img);
    else
        mask = logical(mask);
    end

    [H, W, numC] = size(img);

    sigma = p.Results.Sigma;
    if isempty(sigma)
        sigma = max(15, round(min(H, W) * 0.10));
    end

    imgDbl = double(img);
    normImgDbl = zeros(H, W, numC);
    illumMap = zeros(H, W);

    % Perform correction per channel to preserve color balance
    for c = 1:numC
        channel = imgDbl(:, :, c);
        
        % Inpaint outside background with mean retinal value so boundary black
        % does not distort the low-pass illumination field
        retinaVals = channel(mask);
        if isempty(retinaVals)
            normImg = img;
            return;
        end
        meanRetina = mean(retinaVals);
        
        filledChannel = channel;
        filledChannel(~mask) = meanRetina;
        
        % Estimate low-frequency illumination profile via Gaussian filter
        hSize = round(sigma * 3);
        if mod(hSize, 2) == 0
            hSize = hSize + 1;
        end
        hGauss = fspecial('gaussian', [hSize, hSize], sigma);
        bkgIllum = imfilter(filledChannel, hGauss, 'replicate');
        
        if c == 2
            illumMap = bkgIllum; % Green channel illumination map as reference
        end
        
        % Illumination ratio correction: I_norm = (I / Illum) * TargetMean
        epsVal = 1e-3;
        targetMean = meanRetina;
        corrected = (channel ./ (bkgIllum + epsVal)) * targetMean;
        
        % Clamp to valid intensity range
        corrected(~mask) = 0;
        normImgDbl(:, :, c) = corrected;
    end

    normImg = uint8(max(0, min(255, round(normImgDbl))));
end
