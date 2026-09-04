function [isDetected, nvMask, metrics] = detectNeovascularization(vesselMask, odStruct, retinaMask, varargin)
% DETECTNEOVASCULARIZATION Screens for abnormal vessel proliferation (NVD & NVE).
%
% Clinical Background:
%   Neovascularization is the definitive pathological hallmark of Proliferative
%   Diabetic Retinopathy (PDR, Level 4). It involves fragile, chaotic new vessels
%   growing either at the optic disc (NVD) or elsewhere across the retina (NVE).
%
% Strategy:
%   - Evaluates peripapillary vessel density within 1 disc diameter of the OD (NVD).
%   - Evaluates local vascular cluster complexity and branch density (NVE).
%
% Usage:
%   [isDetected, nvMask, metrics] = detectNeovascularization(vesselMask, odStruct, retinaMask)
%
% Inputs:
%   vesselMask - Binary mask of retinal vessels from segmentVessels.
%   odStruct   - Optic disc structure from locateOpticDisc.
%   retinaMask - Binary mask of retinal field from assessFOV.
%
% Outputs:
%   isDetected - Logical true if neovascularization is suspected.
%   nvMask     - Binary mask of suspected neovascular fronds.
%   metrics    - Struct containing NVD/NVE scores and branch metrics.
%
% Reference:
%   Phase 5: Lesion Detection and Clinical Evidence

    [H, W] = size(vesselMask);

    if nargin < 3 || isempty(retinaMask)
        retinaMask = true(H, W);
    end

    nvMask = false(H, W);
    odCenter = odStruct.center;
    odRadius = odStruct.radius;

    % 1. NVD Analysis (Zone within 1 Disc Diameter of OD margin)
    nvdScore = 0.0;
    nvdSuspected = false;
    
    if ~any(isnan(odCenter)) && ~isnan(odRadius) && odRadius > 0
        [X, Y] = meshgrid(1:W, 1:H);
        distFromOD = sqrt((X - odCenter(1)).^2 + (Y - odCenter(2)).^2);
        
        % Zone between OD boundary (1 * radius) and 1 disc diameter away (3 * radius)
        nvdZone = (distFromOD <= (3.0 * odRadius)) & retinaMask;
        zoneVesselPixels = sum(vesselMask(nvdZone));
        totalZonePixels  = sum(nvdZone(:));

        if totalZonePixels > 0
            nvdDensity = zoneVesselPixels / totalZonePixels;
            % Normal disc vessel density is ~15-28%; chaotic neovascular fronds exceed 38%
            if nvdDensity > 0.38
                nvdSuspected = true;
                nvdScore = min(1.0, (nvdDensity - 0.35) / 0.15);
                nvMask = nvMask | (vesselMask & nvdZone);
            end
        else
            nvdDensity = 0;
        end
    else
        nvdDensity = 0;
    end

    % 2. NVE Analysis (Chaotic branching and dense tangle clusters elsewhere)
    nveSuspected = false;
    nveScore = 0.0;
    branchCount = 0;

    try
        skel = bwskel(vesselMask);
        branches = bwmorph(skel, 'branchpoints');
        branchCount = sum(branches(:));

        % Check for abnormal cluster of branch points (chaotic capillary tangles)
        seCluster = strel('disk', 15);
        branchDensity = imfilter(double(branches), double(seCluster.Neighborhood));
        branchDensity(~retinaMask) = 0;
        
        % If OD exists, mask out normal vascular trunk division at OD
        if ~any(isnan(odCenter)) && odRadius > 0
            branchDensity(distFromOD <= (1.8 * odRadius)) = 0;
        end

        maxCluster = max(branchDensity(:));
        if maxCluster >= 8.0 % Abnormal tangle of tiny vessels
            nveSuspected = true;
            nveScore = min(1.0, (maxCluster - 6.0) / 6.0);
            tangleZone = (branchDensity >= 6.0);
            nvMask = nvMask | (vesselMask & tangleZone);
        end
    catch
        % Morphological fallback
    end

    % 3. Composite Decision
    isDetected = nvdSuspected || nveSuspected;
    
    if nvdSuspected && nveSuspected
        suspectedType = "NVD_AND_NVE";
    elseif nvdSuspected
        suspectedType = "NVD";
    elseif nveSuspected
        suspectedType = "NVE";
    else
        suspectedType = "NONE";
    end

    metrics = struct();
    metrics.detected       = isDetected;
    metrics.type           = suspectedType;
    metrics.nvdDensity     = round(nvdDensity, 3);
    metrics.nvdScore       = round(nvdScore, 2);
    metrics.nveScore       = round(nveScore, 2);
    metrics.totalBranches  = branchCount;
end
