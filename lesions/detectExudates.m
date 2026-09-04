function [exudateMask, candidates, metrics] = detectExudates(img, retinaMask, odMask, varargin)
% DETECTEXUDATES Detects bright lesion candidates (hard and soft exudates).
%
% Clinical Background:
%   Exudates are yellow/white deposits of lipids and lipoproteins leaking from
%   abnormally permeable retinal capillaries. They appear bright in both green
%   and red channels.
%
% Critical Rule:
%   The Optic Disc is naturally bright yellow and MUST be masked out with a
%   margin to prevent catastrophic false-positive exudate detections.
%
% Usage:
%   [exudateMask, candidates, metrics] = detectExudates(img, retinaMask, odMask)
%
% Inputs:
%   img        - RGB fundus image (uint8).
%   retinaMask - (Optional) Logical mask of the retinal field.
%   odMask     - (Optional) Logical mask of the segmented optic disc.
%
% Outputs:
%   exudateMask - Binary mask of detected exudate candidate regions.
%   candidates  - Struct array of connected components (Centroid, Area, BoundingBox).
%   metrics     - Struct containing count and total lesion area.
%
% Reference:
%   Phase 5: Lesion Detection and Clinical Evidence

    p = inputParser;
    addRequired(p, 'img');
    addOptional(p, 'retinaMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
    addOptional(p, 'odMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
    parse(p, img, retinaMask, odMask, varargin{:});

    [H, W, ~] = size(img);

    mask = p.Results.retinaMask;
    if isempty(mask)
        [~, ~, mask] = assessFOV(img);
    else
        mask = logical(mask);
    end

    od = p.Results.odMask;
    if isempty(od)
        [~, od] = locateOpticDisc(img, mask);
    else
        od = logical(od);
    end

    % 1. Dilate Optic Disc mask with a safety buffer (~12 pixels)
    % This eliminates bright peripapillary halos and disc border glare
    seOD = strel('disk', max(8, round(min(H, W) * 0.025)));
    odExclusionZone = imdilate(od, seOD);

    % Effective search area: inside retina and strictly outside optic disc
    searchArea = mask & ~odExclusionZone;

    % 2. Extract Green channel and Intensity channel
    % Exudates have high luminance and sharp local contrast
    if ndims(img) == 3
        % Exudates show strong yellow/white reflectance: high R and G
        intensity = 0.5 * double(img(:, :, 1)) + 0.5 * double(img(:, :, 2));
    else
        intensity = double(img);
    end

    % 3. Morphological Top-Hat to isolate local bright peaks
    % Structural elements: disk radius ~8-12 pixels (typical exudate cluster size)
    seTopHat = strel('disk', 10);
    topHatResp = imtophat(intensity, seTopHat);
    topHatResp(~searchArea) = 0;

    % 4. Adaptive Thresholding for Bright Lesion Candidates
    validPixels = topHatResp(searchArea);
    if isempty(validPixels) || max(validPixels) == 0
        exudateMask = false(H, W);
        candidates = struct([]);
        metrics = struct('count', 0, 'totalArea', 0, 'meanArea', 0);
        return;
    end

    % Exudates have local contrast significantly above local background
    brightCutoff = max(18.0, prctile(validPixels, 98.5));
    rawExudateMask = (topHatResp >= brightCutoff) & searchArea;

    % 5. Morphological Cleanup
    % Remove single-pixel isolated noise (area < 4 px)
    cleanedMask = bwareaopen(rawExudateMask, 4);

    % Exudates are focal deposits; reject abnormally large contiguous areas
    % that represent camera flare or overexposed background (> 1500 px)
    cc = bwconncomp(cleanedMask);
    exudateMask = false(H, W);
    candidateList = [];

    if cc.NumObjects > 0
        props = regionprops(cc, 'Area', 'Centroid', 'BoundingBox', 'Eccentricity');
        keepIdx = [];
        for i = 1:cc.NumObjects
            if props(i).Area <= 1200
                keepIdx(end+1) = i;
                exudateMask(cc.PixelIdxList{i}) = true;
            end
        end

        if ~isempty(keepIdx)
            candidateList = props(keepIdx);
        end
    end

    count = numel(candidateList);
    totalArea = sum(exudateMask(:));
    if count > 0
        meanArea = totalArea / count;
    else
        meanArea = 0;
    end

    candidates = candidateList;
    metrics = struct();
    metrics.count     = count;
    metrics.totalArea = totalArea;
    metrics.meanArea  = round(meanArea, 1);
end
