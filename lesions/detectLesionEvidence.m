function [outSample, evidenceStruct, overlayImg] = detectLesionEvidence(inputArg, varargin)
% DETECTLESIONEVIDENCE Master engine for retinal lesion candidate extraction.
%
% Extracts supporting clinical evidence for Diabetic Retinopathy:
%   1. Microaneurysm candidates (capillary micro-outpouchings)
%   2. Hemorrhage candidates (dot-blot & flame hemorrhages)
%   3. Exudate candidates (lipid leakage plaques with OD masked out)
%   4. Neovascularization screening (abnormal NVD/NVE fronds)
%   5. Multi-color clinical lesion candidate overlay
%
% Critical Clinical Note:
%   Detected regions are classified as "lesion candidates" or "supporting evidence"
%   to assist ophthalmologists and validate CNN explainability. They are not
%   standalone confirmed diagnoses without clinical ground-truth validation.
%
% Usage:
%   sample = detectLesionEvidence(sample)
%   [sample, evidence, overlay] = detectLesionEvidence(sample)
%   [evidence, overlay] = detectLesionEvidence(rawImageMatrix)
%
% Inputs:
%   inputArg - Standard sample struct (with anatomy and quality populated),
%              or raw fundus image matrix.
%
% Outputs:
%   outSample      - Updated sample struct with sample.lesionEvidence populated.
%   evidenceStruct - Detailed lesion evidence candidate struct.
%   overlayImg     - RGB annotated fundus photograph showing candidate markers.
%
% Reference:
%   Phase 5: Lesion Detection and Clinical Evidence

    isSampleStruct = isstruct(inputArg) && isfield(inputArg, 'image');

    if isSampleStruct
        sample = inputArg;
        workingImg = sample.image;

        % Check if Phase 2 and Phase 4 have been executed
        if ~isfield(sample, 'quality') || isempty(sample.quality.retinaMask)
            sample = assessImageQuality(sample);
        end
        retinaMask = sample.quality.retinaMask;

        if ~isfield(sample, 'anatomy') || isempty(sample.anatomy.opticDisc) || isempty(sample.anatomy.opticDisc.mask)
            sample = analyzeRetinalStructures(sample);
        end
        odStruct   = sample.anatomy.opticDisc;
        odMask     = sample.anatomy.opticDisc.mask;
        vesselMask = sample.anatomy.vessels.mask;
    elseif isnumeric(inputArg) || islogical(inputArg)
        workingImg = inputArg;
        sample = [];
        [~, ~, retinaMask] = assessFOV(workingImg);
        [odStruct, odMask] = locateOpticDisc(workingImg, retinaMask);
        [vesselMask, ~]    = segmentVessels(workingImg, retinaMask);
    else
        error('detectLesionEvidence:InvalidInput', 'Input must be a sample struct or image matrix.');
    end

    % 1. Step 1: Detect Microaneurysms
    [maMask, maCandidates, maMetrics] = detectMicroaneurysms(workingImg, retinaMask, vesselMask, odMask);

    % 2. Step 2: Detect Hemorrhages
    [haMask, haCandidates, haMetrics] = detectHemorrhages(workingImg, retinaMask, vesselMask, odMask);

    % 3. Step 3: Detect Exudates (with Optic Disc masked out)
    [exMask, exCandidates, exMetrics] = detectExudates(workingImg, retinaMask, odMask);

    % 4. Step 4: Screen for Neovascularization
    [isNV, nvMask, nvMetrics] = detectNeovascularization(vesselMask, odStruct, retinaMask);

    % 5. Assemble Evidence Struct
    evidenceStruct = struct();
    evidenceStruct.microaneurysms = struct( ...
        'count',      maMetrics.count, ...
        'candidates', maCandidates, ...
        'mask',       maMask ...
    );
    evidenceStruct.hemorrhages = struct( ...
        'count',      haMetrics.count, ...
        'candidates', haCandidates, ...
        'mask',       haMask ...
    );
    evidenceStruct.exudates = struct( ...
        'count',      exMetrics.count, ...
        'candidates', exCandidates, ...
        'mask',       exMask ...
    );
    evidenceStruct.neovascularization = struct( ...
        'detected',   isNV, ...
        'mask',       nvMask, ...
        'metrics',    nvMetrics ...
    );

    totalCandidates = maMetrics.count + haMetrics.count + exMetrics.count;
    evidenceStruct.totalLesions = totalCandidates;
    evidenceStruct.clinicalNotice = "Candidate lesion detections are supporting evidence and not standalone diagnoses.";

    % 6. Step 5: Generate Visual Overlay
    overlayImg = visualizeLesions(workingImg, evidenceStruct);
    evidenceStruct.overlay = overlayImg;

    % Update sample struct
    if isSampleStruct
        sample.lesionEvidence = evidenceStruct;
        outSample = sample;
    else
        outSample = evidenceStruct;
    end
end
