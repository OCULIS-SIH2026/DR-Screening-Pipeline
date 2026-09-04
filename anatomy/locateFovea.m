function [foveaStruct] = locateFovea(img, odStruct, vesselMask, retinaMask, varargin)
% LOCATEFOVEA Estimates the fovea / macula center in a fundus photograph.
%
% Anatomical Context:
%   The fovea centralis is located temporal to the optic disc at approximately
%   2.0 to 2.5 optic disc diameters (ODDs). It is the center of the macula,
%   responsible for high-acuity central vision, and is characterized by the
%   Foveal Avascular Zone (FAZ) and high pigment absorption (dark region).
%
% Usage:
%   foveaStruct = locateFovea(img, odStruct)
%   foveaStruct = locateFovea(img, odStruct, vesselMask, retinaMask)
%
% Inputs:
%   img        - RGB fundus image (uint8).
%   odStruct   - Optic disc structure from locateOpticDisc.
%   vesselMask - (Optional) Binary vessel mask from segmentVessels.
%   retinaMask - (Optional) Binary retinal foreground mask.
%
% Outputs:
%   foveaStruct - Struct containing:
%                   .center              - [x, y] coordinates of fovea
%                   .confidence          - Detection confidence in [0, 1]
%                   .laterality          - "OD" (Right Eye) or "OS" (Left Eye)
%                   .discToFoveaDistance - Distance in pixels from OD center
%
% Reference:
%   Phase 4: Retinal Structure Analysis

    [H, W, ~] = size(img);

    if nargin < 4 || isempty(retinaMask)
        [~, ~, retinaMask] = assessFOV(img);
    end

    if nargin < 3 || isempty(vesselMask)
        vesselMask = false(H, W);
    end

    odCenter = odStruct.center;
    odRadius = odStruct.radius;

    if any(isnan(odCenter)) || isnan(odRadius) || odRadius <= 0
        % Fallback: Center of image if OD was not detected
        foveaStruct = struct('center', [round(W/2), round(H/2)], ...
                             'confidence', 0.20, ...
                             'laterality', "UNKNOWN", ...
                             'discToFoveaDistance', NaN);
        return;
    end

    % 1. Determine Laterality (Eye side)
    % Fundus cameras center the field between the OD and the macula.
    % If OD is to the right of image center (nasal) -> Right Eye (Oculus Dexter, OD)
    % If OD is to the left of image center (nasal)  -> Left Eye (Oculus Sinister, OS)
    frameCenter = W / 2;
    if odCenter(1) >= frameCenter
        laterality = "OD"; % Right eye: fovea is temporal (to the left of OD)
        temporalDir = -1;
    else
        laterality = "OS"; % Left eye: fovea is temporal (to the right of OD)
        temporalDir = 1;
    end

    % 2. Anatomical Distance Estimate
    % Fovea is approximately 2.0 to 2.5 optic disc diameters (4.0 to 5.0 * odRadius)
    nominalDistance = 4.5 * odRadius;
    expectedFoveaX = odCenter(1) + temporalDir * nominalDistance;
    % Fovea is horizontally aligned or slightly inferior (downward) by ~2-5 degrees
    expectedFoveaY = odCenter(2) + 0.15 * odRadius;

    % 3. Search Window around expected location
    winHalfW = round(1.2 * odRadius);
    winHalfH = round(1.0 * odRadius);

    xMin = max(1, round(expectedFoveaX - winHalfW));
    xMax = min(W, round(expectedFoveaX + winHalfW));
    yMin = max(1, round(expectedFoveaY - winHalfH));
    yMax = min(H, round(expectedFoveaY + winHalfH));

    % 4. Search for Intensity Minimum in Macular Region
    % Fovea is dark in Green and Red channels
    if ndims(img) == 3
        maculaChannel = 0.6 * double(img(:, :, 2)) + 0.4 * double(img(:, :, 1));
    else
        maculaChannel = double(img);
    end

    % Exclude blood vessels (fovea lies in avascular zone)
    maculaChannel(vesselMask) = Inf;
    maculaChannel(~retinaMask) = Inf;

    searchWindow = maculaChannel(yMin:yMax, xMin:xMax);

    if ~all(isinf(searchWindow(:)))
        % Smooth slightly to ignore single-pixel dark noise
        hSmooth = fspecial('gaussian', [5, 5], 1.5);
        smoothedWin = imfilter(searchWindow, hSmooth, 'replicate');
        
        [~, minIdx] = min(smoothedWin(:));
        [relY, relX] = ind2sub(size(searchWindow), minIdx);
        
        foveaX = xMin + relX - 1;
        foveaY = yMin + relY - 1;
        conf = 0.85;
    else
        foveaX = expectedFoveaX;
        foveaY = expectedFoveaY;
        conf = 0.50;
    end

    % Bound to image coordinates
    foveaX = max(1, min(W, round(foveaX)));
    foveaY = max(1, min(H, round(foveaY)));

    distToOD = norm([foveaX - odCenter(1), foveaY - odCenter(2)]);

    foveaStruct = struct();
    foveaStruct.center              = [foveaX, foveaY];
    foveaStruct.confidence          = min(1.0, max(0.0, conf));
    foveaStruct.laterality          = laterality;
    foveaStruct.discToFoveaDistance = round(distToOD, 1);
end
