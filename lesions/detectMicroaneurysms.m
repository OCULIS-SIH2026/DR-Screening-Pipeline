function [maMask, candidates, metrics] = detectMicroaneurysms(img, retinaMask, vesselMask, odMask, varargin)
% DETECTMICROANEURYSMS Detects microaneurysm candidates in fundus photographs.
%
% Clinical Background:
%   Microaneurysms (MAs) are the earliest clinically visible hallmark of
%   diabetic retinopathy (defining Mild NPDR, Level 1). They appear as tiny,
%   focal, dark-red circular lesions (< 125 microns) branching off capillaries.
%
% Challenge & Strategy:
%   MAs are easily confused with vessel intersections or noise. We apply
%   bottom-hat morphological filtering, subtract the segmented blood vessels,
%   and apply strict circularity and area constraints.
%
% Usage:
%   [maMask, candidates, metrics] = detectMicroaneurysms(img, retinaMask, vesselMask, odMask)
%
% Inputs:
%   img        - RGB fundus image (uint8).
%   retinaMask - (Optional) Logical mask of the retinal field.
%   vesselMask - (Optional) Logical mask of the segmented blood vessels.
%   odMask     - (Optional) Logical mask of the optic disc.
%
% Outputs:
%   maMask     - Binary mask of detected microaneurysm candidate regions.
%   candidates - Struct array of connected components (Centroid, Area, Eccentricity).
%   metrics    - Struct containing count and candidate density.
%
% Reference:
%   Phase 5: Lesion Detection and Clinical Evidence

    p = inputParser;
    addRequired(p, 'img');
    addOptional(p, 'retinaMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
    addOptional(p, 'vesselMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
    addOptional(p, 'odMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
    parse(p, img, retinaMask, vesselMask, odMask, varargin{:});

    [H, W, ~] = size(img);

    mask = p.Results.retinaMask;
    if isempty(mask)
        [~, ~, mask] = assessFOV(img);
    else
        mask = logical(mask);
    end

    vessels = p.Results.vesselMask;
    if isempty(vessels)
        vessels = segmentVessels(img, mask);
    else
        vessels = logical(vessels);
    end

    od = p.Results.odMask;
    if isempty(od)
        [~, od] = locateOpticDisc(img, mask);
    else
        od = logical(od);
    end

    % 1. Buffer vessels and optic disc to eliminate false positives on vessel trunks
    seVessel = strel('disk', 2);
    vesselBuffer = imdilate(vessels, seVessel);

    seOD = strel('disk', 8);
    odBuffer = imdilate(od, seOD);

    searchArea = mask & ~vesselBuffer & ~odBuffer;

    % 2. Extract Green Channel (maximum hemoglobin absorption)
    if ndims(img) == 3
        G = double(img(:, :, 2));
    else
        G = double(img);
    end

    % 3. Morphological Bottom-Hat Transform (isolates dark circular dots)
    % Radius 4 corresponds to typical microaneurysm size
    seDot = strel('disk', 4);
    botHat = imbothat(G, seDot);
    botHat(~searchArea) = 0;

    % 4. Adaptive Thresholding
    validPixels = botHat(searchArea);
    if isempty(validPixels) || max(validPixels) == 0
        maMask = false(H, W);
        candidates = struct([]);
        metrics = struct('count', 0, 'totalArea', 0);
        return;
    end

    % Microaneurysms exhibit high local bottom-hat contrast
    dotThreshold = max(12.0, prctile(validPixels, 99.2));
    rawCandidates = (botHat >= dotThreshold) & searchArea;

    % 5. Size and Circularity Filtering
    % MAs are tiny (area typically 2 to 35 pixels) and compact (eccentricity < 0.85)
    cc = bwconncomp(rawCandidates);
    maMask = false(H, W);
    candidateList = [];

    if cc.NumObjects > 0
        props = regionprops(cc, 'Area', 'Centroid', 'Eccentricity', 'BoundingBox');
        keepIdx = [];
        for i = 1:cc.NumObjects
            a = props(i).Area;
            ecc = props(i).Eccentricity;
            if a >= 2 && a <= 35 && ecc <= 0.85
                keepIdx(end+1) = i;
                maMask(cc.PixelIdxList{i}) = true;
            end
        end

        if ~isempty(keepIdx)
            candidateList = props(keepIdx);
        end
    end

    candidates = candidateList;
    metrics = struct();
    metrics.count     = numel(candidateList);
    metrics.totalArea = sum(maMask(:));
end
