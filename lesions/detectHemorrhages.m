function [haMask, candidates, metrics] = detectHemorrhages(img, retinaMask, vesselMask, odMask, varargin)
% DETECTHEMORRHAGES Detects retinal hemorrhage candidates (dot-blot & flame hemorrhages).
%
% Clinical Background:
%   Retinal hemorrhages result from vascular damage and capillary breakdown.
%   They appear as dark red/brown patches, larger and more irregular than
%   microaneurysms, and are primary indicators of Moderate to Severe NPDR.
%
% Usage:
%   [haMask, candidates, metrics] = detectHemorrhages(img, retinaMask, vesselMask, odMask)
%
% Inputs:
%   img        - RGB fundus image (uint8).
%   retinaMask - (Optional) Logical mask of the retinal field.
%   vesselMask - (Optional) Logical mask of the segmented blood vessels.
%   odMask     - (Optional) Logical mask of the optic disc.
%
% Outputs:
%   haMask     - Binary mask of detected hemorrhage candidate regions.
%   candidates - Struct array of connected components (Centroid, Area, BoundingBox).
%   metrics    - Struct containing count and total lesion area.
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

    % 1. Exclude major vessels and optic disc
    seVessel = strel('disk', 3);
    vesselBuffer = imdilate(vessels, seVessel);

    seOD = strel('disk', 10);
    odBuffer = imdilate(od, seOD);

    searchArea = mask & ~vesselBuffer & ~odBuffer;

    % 2. Multi-scale Dark Lesion Detection on Green Channel
    if ndims(img) == 3
        G = double(img(:, :, 2));
        R = double(img(:, :, 1));
    else
        G = double(img);
        R = G;
    end

    % Medium-to-large bottom-hat filtering (disk radius 10)
    seMedium = strel('disk', 10);
    botHatMed = imbothat(G, seMedium);
    botHatMed(~searchArea) = 0;

    validPixels = botHatMed(searchArea);
    if isempty(validPixels) || max(validPixels) == 0
        haMask = false(H, W);
        candidates = struct([]);
        metrics = struct('count', 0, 'totalArea', 0);
        return;
    end

    % 3. Adaptive Thresholding
    haCutoff = max(14.0, prctile(validPixels, 98.8));
    rawHemorrhages = (botHatMed >= haCutoff) & searchArea;

    % 4. Area and Color Ratio Filtering
    % Hemorrhages are larger than microaneurysms (area > 35 px) up to 1500 px
    cc = bwconncomp(rawHemorrhages);
    haMask = false(H, W);
    candidateList = [];

    if cc.NumObjects > 0
        props = regionprops(cc, 'Area', 'Centroid', 'BoundingBox');
        keepIdx = [];
        for i = 1:cc.NumObjects
            a = props(i).Area;
            if a > 35 && a <= 1500
                % Verify red/green blood absorption ratio
                pxList = cc.PixelIdxList{i};
                meanR = mean(R(pxList));
                meanG = mean(G(pxList));
                
                % Blood has higher reflectance in Red than Green
                if meanR >= meanG * 1.05
                    keepIdx(end+1) = i;
                    haMask(pxList) = true;
                end
            end
        end

        if ~isempty(keepIdx)
            candidateList = props(keepIdx);
        end
    end

    candidates = candidateList;
    metrics = struct();
    metrics.count     = numel(candidateList);
    metrics.totalArea = sum(haMask(:));
end
