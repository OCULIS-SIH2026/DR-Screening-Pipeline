function overlayImg = visualizeLesions(img, evidenceStruct, varargin)
% VISUALIZELESIONS Overlays detected lesion candidates on a fundus photograph.
%
% Visual Legend:
%   - Red circles:           Microaneurysm candidates
%   - Crimson filled:        Hemorrhage candidates
%   - Yellow / Lime contours: Exudate candidates (lipid plaques)
%   - Magenta highlights:    Neovascularization candidates
%
% Usage:
%   overlayImg = visualizeLesions(img, evidenceStruct)
%   visualizeLesions(img, evidenceStruct, 'Display', true)
%
% Inputs:
%   img            - RGB fundus image (uint8).
%   evidenceStruct - Struct from detectLesionEvidence.
%
% Outputs:
%   overlayImg     - RGB annotated image with color-coded lesion evidence.
%
% Reference:
%   Phase 5: Lesion Detection and Clinical Evidence

    p = inputParser;
    addRequired(p, 'img');
    addRequired(p, 'evidenceStruct');
    addParameter(p, 'Display', false, @(x) islogical(x) || isnumeric(x));
    parse(p, img, evidenceStruct, varargin{:});

    shouldDisplay = logical(p.Results.Display);
    [H, W, ~] = size(img);
    overlayImg = img;

    % 1. Overlay Hemorrhages (Deep Crimson tint: R=200, G=20, B=20, 50% opacity)
    if isfield(evidenceStruct, 'hemorrhages') && isfield(evidenceStruct.hemorrhages, 'mask') && ...
       ~isempty(evidenceStruct.hemorrhages.mask)
        haMask = evidenceStruct.hemorrhages.mask;
        for c = 1:3
            ch = double(overlayImg(:, :, c));
            if c == 1
                colorVal = 220;
            else
                colorVal = 20;
            end
            ch(haMask) = 0.50 * ch(haMask) + 0.50 * colorVal;
            overlayImg(:, :, c) = uint8(ch);
        end
    end

    % 2. Overlay Exudates (Bright Yellow outlines: R=255, G=240, B=0)
    if isfield(evidenceStruct, 'exudates') && isfield(evidenceStruct.exudates, 'mask') && ...
       ~isempty(evidenceStruct.exudates.mask)
        exMask = evidenceStruct.exudates.mask;
        % Extract perimeter of exudates
        exPerim = bwperim(exMask);
        seDil = strel('disk', 1);
        exPerimThick = imdilate(exPerim, seDil);
        for c = 1:3
            ch = overlayImg(:, :, c);
            if c == 3
                ch(exPerimThick) = 0; % R=255, G=240, B=0
            elseif c == 2
                ch(exPerimThick) = 240;
            else
                ch(exPerimThick) = 255;
            end
            overlayImg(:, :, c) = ch;
        end
    end

    % 3. Overlay Microaneurysms (Red circle rings: R=255, G=30, B=30)
    if isfield(evidenceStruct, 'microaneurysms') && isfield(evidenceStruct.microaneurysms, 'candidates') && ...
       ~isempty(evidenceStruct.microaneurysms.candidates)
        candidates = evidenceStruct.microaneurysms.candidates;
        for i = 1:numel(candidates)
            c = candidates(i).Centroid;
            cx = round(c(1));
            cy = round(c(2));
            ringRad = 5;
            theta = linspace(0, 2*pi, 40);
            rx = round(cx + ringRad * cos(theta));
            ry = round(cy + ringRad * sin(theta));
            validPts = rx >= 1 & rx <= W & ry >= 1 & ry <= H;
            for pt = 1:numel(validPts)
                if validPts(pt)
                    overlayImg(ry(pt), rx(pt), :) = [255, 30, 30];
                end
            end
        end
    end

    % 4. Overlay Neovascularization if detected (Magenta: R=255, G=0, B=255)
    if isfield(evidenceStruct, 'neovascularization') && isfield(evidenceStruct.neovascularization, 'mask') && ...
       ~isempty(evidenceStruct.neovascularization.mask)
        nvMask = evidenceStruct.neovascularization.mask;
        for c = 1:3
            ch = double(overlayImg(:, :, c));
            if c == 2
                colorVal = 0;
            else
                colorVal = 255;
            end
            ch(nvMask) = 0.40 * ch(nvMask) + 0.60 * colorVal;
            overlayImg(:, :, c) = uint8(ch);
        end
    end

    if shouldDisplay
        figure('Name', 'Retinal Lesion Evidence Candidates', 'NumberTitle', 'off');
        imshow(overlayImg);
        title('Supporting Clinical Lesion Candidates');
    end
end
