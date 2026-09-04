function [outSample, anatomyStruct, overlayImg] = analyzeRetinalStructures(inputArg, varargin)
% ANALYZERETINALSTRUCTURES Master anatomical analysis engine for fundus screening.
%
% Coordinates:
%   1. Optic Disc localization and segmentation
%   2. Retinal blood vessel tree segmentation (density & morphology)
%   3. Fovea / Macula center estimation based on OD geometry
%   4. Visual anatomical map overlay generation
%
% Usage:
%   sample = analyzeRetinalStructures(sample)
%   [sample, anatomy, overlay] = analyzeRetinalStructures(sample)
%   [anatomy, overlay] = analyzeRetinalStructures(rawImageMatrix)
%
% Inputs:
%   inputArg - Standard sample struct (from Phase 1/2/3) or raw image matrix.
%
% Outputs:
%   outSample     - Updated sample struct with sample.anatomy populated.
%   anatomyStruct - Detailed anatomical landmark struct.
%   overlayImg    - RGB annotated fundus map.
%
% Reference:
%   Phase 4: Retinal Structure Analysis

    isSampleStruct = isstruct(inputArg) && isfield(inputArg, 'image');

    if isSampleStruct
        sample = inputArg;
        % Choose best available image: enhanced if available, else standard image
        if isfield(sample, 'enhancementInfo') && sample.enhancementInfo.applied && ...
           ~isempty(sample.enhancedImage)
            workingImg = sample.enhancedImage;
        else
            workingImg = sample.image;
        end

        % Extract or compute retina mask
        if isfield(sample, 'quality') && isfield(sample.quality, 'retinaMask') && ...
           ~isempty(sample.quality.retinaMask)
            retinaMask = sample.quality.retinaMask;
        else
            [~, ~, retinaMask] = assessFOV(workingImg);
        end
    elseif isnumeric(inputArg) || islogical(inputArg)
        workingImg = inputArg;
        sample = [];
        [~, ~, retinaMask] = assessFOV(workingImg);
    elseif isstring(inputArg) || ischar(inputArg)
        sample = loadFundusImage(inputArg);
        workingImg = sample.image;
        [~, ~, retinaMask] = assessFOV(workingImg);
        isSampleStruct = true;
    else
        error('analyzeRetinalStructures:InvalidInput', 'Input must be a sample struct, image matrix, or path.');
    end

    % 1. Step 1: Locate and Segment Optic Disc
    [odStruct, odMask] = locateOpticDisc(workingImg, retinaMask);

    % 2. Step 2: Segment Blood Vessels
    [vesselMask, vesselMetrics] = segmentVessels(workingImg, retinaMask);

    % 3. Step 3: Locate Fovea (Macular Center)
    foveaStruct = locateFovea(workingImg, odStruct, vesselMask, retinaMask);

    % 4. Assemble Master Anatomy Struct
    anatomyStruct = struct();
    anatomyStruct.opticDisc = odStruct;
    anatomyStruct.fovea     = foveaStruct;
    anatomyStruct.vessels   = struct( ...
        'mask',        vesselMask, ...
        'density',     vesselMetrics.density, ...
        'totalPixels', vesselMetrics.totalVesselPixels, ...
        'numBranches', vesselMetrics.numBranches ...
    );

    % 5. Step 4: Generate Clinical Overlay Visualization
    overlayImg = visualizeAnatomy(workingImg, anatomyStruct);
    anatomyStruct.overlay = overlayImg;

    % Update sample struct
    if isSampleStruct
        sample.anatomy = anatomyStruct;
        outSample = sample;
    else
        outSample = anatomyStruct;
    end
end
