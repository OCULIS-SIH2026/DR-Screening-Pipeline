function [vesselMask, metrics] = segmentVessels(img, retinaMask, varargin)
% SEGMENTVESSELS Segments the retinal vascular tree using multi-scale morphological filtering.
%
% Anatomical Context:
%   Retinal blood vessels (arterioles and venules) exhibit strong hemoglobin
%   absorption in the green spectrum, appearing as dark curvilinear structures.
%   Accurate vessel segmentation provides structural context for microaneurysm
%   detection (which attach to vessels) and neovascularization analysis.
%
% Usage:
%   vesselMask = segmentVessels(img)
%   [vesselMask, metrics] = segmentVessels(img, retinaMask)
%   [vesselMask, metrics] = segmentVessels(img, retinaMask, 'Threshold', 'adaptive')
%
% Inputs:
%   img        - RGB fundus image (uint8).
%   retinaMask - (Optional) Logical mask of the retinal field.
%
% Name-Value Parameters:
%   'Threshold' - 'adaptive' (default) or 'otsu'.
%   'LineLength' - Length of linear structuring elements in pixels (default: 11).
%
% Outputs:
%   vesselMask - Binary logical mask of segmented retinal vessels.
%   metrics    - Struct containing:
%                  .density        - Vessel area / total retinal area (typically 8-16%)
%                  .totalVesselPixels
%                  .numBranches    - Approximate branch count from skeleton
%
% Reference:
%   Phase 4: Retinal Structure Analysis

    p = inputParser;
    addRequired(p, 'img');
    addOptional(p, 'retinaMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
    addParameter(p, 'Threshold', 'adaptive', @(x) ischar(x) || isstring(x));
    addParameter(p, 'LineLength', 11, @(x) isnumeric(x) && x > 0);
    parse(p, img, retinaMask, varargin{:});

    mask = p.Results.retinaMask;
    if isempty(mask)
        [~, ~, mask] = assessFOV(img);
    else
        mask = logical(mask);
    end

    threshMethod = lower(char(p.Results.Threshold));
    lineLen      = round(p.Results.LineLength);

    [H, W, ~] = size(img);

    % 1. Extract Green Channel (highest vessel-to-background contrast)
    if ndims(img) == 3
        G = img(:, :, 2);
    else
        G = img;
    end

    % 2. Contrast enhancement via CLAHE on inverted green channel
    % Inverting makes vessels bright features on dark background
    G_inv = imcomplement(G);
    G_inv(~mask) = 0;
    
    % Gentle CLAHE to boost fine vessel branches
    G_enhanced = adapthisteq(G_inv, 'ClipLimit', 0.02, 'NumTiles', [8, 8]);
    G_enhanced(~mask) = 0;

    % 3. Multi-directional morphological line detection
    % Blood vessels run in all orientations (0 to 165 degrees)
    angles = 0:15:165;
    maxLineResponse = zeros(H, W);

    for theta = angles
        seLine = strel('line', lineLen, theta);
        % Top-hat isolates bright linear features aligned with angle theta
        lineResp = imtophat(G_enhanced, seLine);
        maxLineResponse = max(maxLineResponse, double(lineResp));
    end

    % 4. Normalize response inside retina
    retinaVals = maxLineResponse(mask);
    if isempty(retinaVals) || max(retinaVals) == 0
        vesselMask = false(H, W);
        metrics = struct('density', 0, 'totalVesselPixels', 0, 'numBranches', 0);
        return;
    end

    normResponse = maxLineResponse / max(retinaVals);

    % 5. Binarization
    switch threshMethod
        case 'otsu'
            T = graythresh(normResponse(mask));
            vesselBin = (normResponse > (T * 0.85)) & mask;
        otherwise % 'adaptive'
            % Adaptive threshold based on mean + factor * std of local vesselness
            meanVal = mean(retinaVals);
            stdVal  = std(retinaVals);
            rawCutoff = meanVal + 0.35 * stdVal;
            T = rawCutoff / max(retinaVals);
            vesselBin = (normResponse > T) & mask;
    end

    % 6. Clean-up: remove isolated noise specks (area < 20 pixels)
    vesselClean = bwareaopen(vesselBin, 20);

    % Erode outer edge slightly to avoid perimeter false vessels
    seErode = strel('disk', 3);
    innerRetina = imerode(mask, seErode);
    vesselMask = vesselClean & innerRetina;

    % 7. Calculate Vessel Density and Structural Metrics
    totalRetinaPx = sum(mask(:));
    totalVesselPx = sum(vesselMask(:));
    
    if totalRetinaPx > 0
        density = totalVesselPx / totalRetinaPx;
    else
        density = 0;
    end

    % Approximate branch points via skeletonization if available
    numBranches = 0;
    try
        skel = bwskel(vesselMask);
        % Endpoints and branchpoints
        branchPoints = bwmorph(skel, 'branchpoints');
        numBranches  = sum(branchPoints(:));
    catch
        % Fallback if bwskel not present
    end

    metrics = struct();
    metrics.density           = round(density, 4);
    metrics.totalVesselPixels = totalVesselPx;
    metrics.numBranches       = numBranches;
    metrics.vesselMask        = vesselMask;
end
