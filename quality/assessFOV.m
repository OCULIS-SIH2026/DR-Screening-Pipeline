function [fovScore, metrics, retinaMask] = assessFOV(img)
% ASSESSFOV Evaluates the retinal field of view (FOV) and creates a foreground mask.
%
% Usage:
%   [fovScore, metrics, retinaMask] = assessFOV(img)
%
% Inputs:
%   img - RGB (uint8) fundus photograph.
%
% Outputs:
%   fovScore   - Normalized score in [0.0, 1.0].
%   metrics    - Struct containing:
%                  .retinalAreaRatio (foreground px / total px)
%                  .boundaryCircularity (measure of circular field completeness)
%                  .centroidOffset (distance from image center)
%   retinaMask - Binary mask of the retinal foreground (true = retina, false = background).
%
% Reference:
%   Phase 2 of DR_Screening_10_Phase_Implementation_Plan.md

    if ndims(img) == 3
        % Use red and green channels to distinguish retinal tissue from black border
        grayVal = 0.5 * double(img(:,:,1)) + 0.5 * double(img(:,:,2));
    else
        grayVal = double(img);
    end

    [H, W] = size(grayVal);
    totalPixels = H * W;

    % 1. Segment foreground retina from black perimeter
    % Fundus cameras have black borders (typically pixel values < 15-25)
    thresh = max(12, min(35, 0.10 * prctile(grayVal(:), 95)));
    initialMask = grayVal > thresh;

    % Clean mask: fill holes from dark vessels/macula, remove small noise specks
    se = strel('disk', max(3, round(min(H, W) * 0.015)));
    cleanedMask = imclose(initialMask, se);
    cleanedMask = imfill(cleanedMask, 'holes');

    % Retain only the largest connected component (the main retinal circle)
    cc = bwconncomp(cleanedMask);
    if cc.NumObjects > 0
        numPixels = cellfun(@numel, cc.PixelIdxList);
        [maxPixels, maxIdx] = max(numPixels);
        retinaMask = false(size(cleanedMask));
        retinaMask(cc.PixelIdxList{maxIdx}) = true;
    else
        retinaMask = false(H, W);
        maxPixels = 0;
    end

    % 2. Calculate area ratio
    retinalAreaRatio = maxPixels / totalPixels;

    % 3. Calculate centroid offset from frame center
    if maxPixels > 0
        props = regionprops(retinaMask, 'Centroid', 'Circularity');
        centroid = props(1).Centroid;
        circularity = 1.0;
        if isfield(props, 'Circularity') && ~isempty(props(1).Circularity)
            circularity = min(1.0, props(1).Circularity);
        end

        frameCenter = [W / 2, H / 2];
        distFromCenter = norm(centroid - frameCenter) / (min(W, H) / 2);
    else
        circularity = 0;
        distFromCenter = 1.0;
    end

    % 4. Normal field of view covers ~45% to 80% of typical fundus image sensor
    % Penalize if coverage is < 35% (clipped) or centering is very displaced
    if retinalAreaRatio < 0.20
        areaScore = retinalAreaRatio / 0.20 * 0.40;
    elseif retinalAreaRatio < 0.45
        areaScore = 0.40 + (retinalAreaRatio - 0.20) / (0.45 - 0.20) * 0.45;
    else
        areaScore = min(1.0, 0.85 + (retinalAreaRatio - 0.45) * 0.3);
    end

    centeringScore = max(0, 1.0 - 0.5 * distFromCenter);
    fovScore = min(1.0, max(0.0, 0.70 * areaScore + 0.30 * centeringScore));

    metrics = struct();
    metrics.retinalAreaRatio     = retinalAreaRatio;
    metrics.boundaryCircularity  = circularity;
    metrics.centeringOffsetRatio = distFromCenter;
    metrics.fovScore             = fovScore;
end
