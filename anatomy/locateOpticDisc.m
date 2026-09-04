function [odStruct, odMask] = locateOpticDisc(img, retinaMask, varargin)
% LOCATEOPTICDISC Detects and segments the optic disc in a fundus image.
%
% Anatomical Context:
%   The optic disc (OD) is the brightest circular/elliptical landmark in the
%   retina, marking the exit point of retinal vessels and the optic nerve.
%   Accurate detection is required for fovea localization and preventing false
%   positives in Phase 5 (exudate detection, since both are bright).
%
% Usage:
%   [odStruct, odMask] = locateOpticDisc(img)
%   [odStruct, odMask] = locateOpticDisc(img, retinaMask)
%
% Inputs:
%   img        - RGB fundus image (uint8).
%   retinaMask - (Optional) Logical mask of the retinal field.
%
% Outputs:
%   odStruct   - Struct containing:
%                  .center - [x, y] coordinates of OD center
%                  .radius - Estimated disc radius in pixels
%                  .bbox   - [x, y, width, height] bounding box
%                  .confidence - Detection confidence in [0, 1]
%   odMask     - Binary mask of the segmented optic disc region.
%
% Reference:
%   Phase 4: Retinal Structure Analysis

    p = inputParser;
    addRequired(p, 'img');
    addOptional(p, 'retinaMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
    parse(p, img, retinaMask, varargin{:});

    mask = p.Results.retinaMask;
    if isempty(mask)
        [~, ~, mask] = assessFOV(img);
    else
        mask = logical(mask);
    end

    [H, W, ~] = size(img);
    imgDbl = double(img);

    % 1. Create candidate luminance channel
    % Red + Green channels have high reflectance in the optic disc
    intensity = 0.5 * imgDbl(:, :, 1) + 0.5 * imgDbl(:, :, 2);
    intensity(~mask) = 0;

    % Estimated expected optic disc diameter is ~10% to 18% of retinal field dimension
    propsRetina = regionprops(mask, 'BoundingBox', 'EquivDiameter');
    if ~isempty(propsRetina)
        fieldDiam = propsRetina(1).EquivDiameter;
    else
        fieldDiam = min(H, W);
    end
    expectedRadius = round(fieldDiam * 0.07); % Disc radius ~7% of field
    minRadius = max(6, round(fieldDiam * 0.035));
    maxRadius = max(minRadius + 5, round(fieldDiam * 0.12));

    % 2. Morphological smoothing to blend intra-disc vessel branches
    % Closing with disk removes dark vessel lines passing through the bright disc
    seClose = strel('disk', max(3, round(expectedRadius * 0.40)));
    smoothed = imclose(intensity, seClose);

    % 3. Top-hat filtering / High percentile thresholding
    % Optic disc is among the top 1.5% to 3.0% brightest pixels in the retinal area
    retinaPixels = smoothed(mask);
    if isempty(retinaPixels)
        odStruct = emptyODStruct();
        odMask = false(H, W);
        return;
    end

    brightThresh = prctile(retinaPixels, 98.0);
    brightMask = (smoothed >= brightThresh) & mask;

    % Fill small gaps in the bright mask
    seClean = strel('disk', max(2, round(minRadius * 0.3)));
    brightMask = imclose(brightMask, seClean);
    brightMask = imfill(brightMask, 'holes');

    % 4. Identify best candidate component using compactness and area
    cc = bwconncomp(brightMask);
    bestScore = -1;
    bestIdx = 0;

    if cc.NumObjects > 0
        props = regionprops(cc, 'Area', 'Centroid', 'BoundingBox', 'Eccentricity', 'Circularity');
        expectedArea = pi * (expectedRadius^2);

        for i = 1:cc.NumObjects
            a = props(i).Area;
            ecc = props(i).Eccentricity;
            
            % Check area plausibility
            areaRatio = min(a, expectedArea) / max(a, expectedArea);
            
            % Discs are fairly circular (eccentricity close to 0)
            circularityScore = 1.0 - ecc;
            
            % Combined score
            candidateScore = 0.55 * circularityScore + 0.45 * areaRatio;

            if candidateScore > bestScore && a >= (pi * minRadius^2 * 0.3)
                bestScore = candidateScore;
                bestIdx = i;
            end
        end
    end

    % 5. Secondary fallback: Circular Hough Transform if connected components are ambiguous
    usedHough = false;
    if bestIdx == 0 || bestScore < 0.25
        try
            [centers, radii, metric] = imfindcircles(uint8(intensity), [minRadius, maxRadius], ...
                'ObjectPolarity', 'bright', 'Sensitivity', 0.88);
            if ~isempty(centers)
                % Filter circles to ensure center is within retina
                for cIdx = 1:size(centers, 1)
                    cx = round(centers(cIdx, 1));
                    cy = round(centers(cIdx, 2));
                    if cx >= 1 && cx <= W && cy >= 1 && cy <= H && mask(cy, cx)
                        odCenter = [centers(cIdx, 1), centers(cIdx, 2)];
                        odRadius = radii(cIdx);
                        bestScore = metric(cIdx);
                        usedHough = true;
                        break;
                    end
                end
            end
        catch
            % imfindcircles not applicable
        end
    end

    % 6. Construct final mask and properties
    if bestIdx > 0 && ~usedHough
        odCenter = props(bestIdx).Centroid;
        % Derive radius from equivalent area: Area = pi * r^2
        odRadius = sqrt(props(bestIdx).Area / pi);
        odRadius = max(minRadius, min(maxRadius, odRadius));
        odBbox   = props(bestIdx).BoundingBox;
        
        % Generate smoothed circular mask centered at detected location
        [X, Y] = meshgrid(1:W, 1:H);
        odMask = ((X - odCenter(1)).^2 + (Y - odCenter(2)).^2) <= (odRadius^2);
        odMask = odMask & mask;
    elseif usedHough
        [X, Y] = meshgrid(1:W, 1:H);
        odMask = ((X - odCenter(1)).^2 + (Y - odCenter(2)).^2) <= (odRadius^2);
        odMask = odMask & mask;
        odBbox = [odCenter(1) - odRadius, odCenter(2) - odRadius, 2 * odRadius, 2 * odRadius];
    else
        % Default conservative estimate (fallback to brightest centroid)
        [~, maxLinIdx] = max(intensity(:));
        [cy, cx] = ind2sub([H, W], maxLinIdx);
        odCenter = [cx, cy];
        odRadius = expectedRadius;
        [X, Y] = meshgrid(1:W, 1:H);
        odMask = ((X - cx).^2 + (Y - cy).^2) <= (odRadius^2) & mask;
        odBbox = [cx - odRadius, cy - odRadius, 2 * odRadius, 2 * odRadius];
        bestScore = 0.30;
    end

    odStruct = struct();
    odStruct.center     = round(odCenter, 1);
    odStruct.radius     = round(odRadius, 1);
    odStruct.bbox       = round(odBbox, 1);
    odStruct.confidence = min(1.0, max(0.0, bestScore));
    odStruct.mask       = odMask;
end

function s = emptyODStruct()
    s = struct('center', [NaN, NaN], 'radius', NaN, 'bbox', [NaN, NaN, NaN, NaN], ...
               'confidence', 0.0, 'mask', []);
end
