function overlayImg = visualizeAnatomy(img, anatomyStruct, varargin)
% VISUALIZEANATOMY Generates a clinical anatomical overlay of retinal structures.
%
% Visualizes:
%   - Blood vessel tree (cyan/green highlight)
%   - Optic Disc (yellow boundary outline + center mark)
%   - Fovea / Macula (crosshair target marker)
%
% Usage:
%   overlayImg = visualizeAnatomy(img, anatomyStruct)
%   visualizeAnatomy(img, anatomyStruct, 'Display', true)
%
% Inputs:
%   img           - RGB fundus image (uint8).
%   anatomyStruct - Anatomy struct from analyzeRetinalStructures.
%
% Name-Value Parameters:
%   'Display' - Logical. If true, renders a MATLAB figure (default: false).
%
% Output:
%   overlayImg    - RGB annotated composite image (uint8).
%
% Reference:
%   Phase 4: Retinal Structure Analysis

    p = inputParser;
    addRequired(p, 'img');
    addRequired(p, 'anatomyStruct');
    addParameter(p, 'Display', false, @(x) islogical(x) || isnumeric(x));
    parse(p, img, anatomyStruct, varargin{:});

    shouldDisplay = logical(p.Results.Display);

    [H, W, ~] = size(img);
    overlayImg = img;

    % 1. Overlay Blood Vessels (Cyan tint: R=0, G=220, B=240)
    if isfield(anatomyStruct, 'vessels') && ~isempty(anatomyStruct.vessels.mask)
        vMask = anatomyStruct.vessels.mask;
        % Blend vessels with original image (60% vessel color, 40% original)
        for c = 1:3
            ch = double(overlayImg(:, :, c));
            if c == 1
                vColor = 30;
            elseif c == 2
                vColor = 230;
            else
                vColor = 240;
            end
            ch(vMask) = 0.40 * ch(vMask) + 0.60 * vColor;
            overlayImg(:, :, c) = uint8(ch);
        end
    end

    % 2. Overlay Optic Disc Outline (Golden Yellow: R=255, G=215, B=0)
    if isfield(anatomyStruct, 'opticDisc') && ~isempty(anatomyStruct.opticDisc.center)
        odCenter = anatomyStruct.opticDisc.center;
        odRadius = anatomyStruct.opticDisc.radius;

        if ~any(isnan(odCenter)) && ~isnan(odRadius) && odRadius > 0
            % Draw circular perimeter
            theta = linspace(0, 2*pi, 360);
            circX = round(odCenter(1) + odRadius * cos(theta));
            circY = round(odCenter(2) + odRadius * sin(theta));

            validPts = circX >= 1 & circX <= W & circY >= 1 & circY <= H;
            circX = circX(validPts);
            circY = circY(validPts);

            % Dilate perimeter line to 2px thickness
            for dx = -1:1
                for dy = -1:1
                    pxX = max(1, min(W, circX + dx));
                    pxY = max(1, min(H, circY + dy));
                    for i = 1:numel(pxX)
                        overlayImg(pxY(i), pxX(i), :) = [255, 215, 0];
                    end
                end
            end

            % Center marker (+)
            cx = round(odCenter(1));
            cy = round(odCenter(2));
            for d = -4:4
                if (cx+d) >= 1 && (cx+d) <= W && cy >= 1 && cy <= H
                    overlayImg(cy, cx+d, :) = [255, 215, 0];
                end
                if cx >= 1 && cx <= W && (cy+d) >= 1 && (cy+d) <= H
                    overlayImg(cy+d, cx, :) = [255, 215, 0];
                end
            end
        end
    end

    % 3. Overlay Fovea Crosshair (Coral Red / Magenta: R=255, G=60, B=60)
    if isfield(anatomyStruct, 'fovea') && ~isempty(anatomyStruct.fovea.center)
        fCenter = anatomyStruct.fovea.center;
        if ~any(isnan(fCenter))
            fx = round(fCenter(1));
            fy = round(fCenter(2));

            % Draw target circle (radius 8px)
            fRad = 8;
            theta = linspace(0, 2*pi, 120);
            tx = round(fx + fRad * cos(theta));
            ty = round(fy + fRad * sin(theta));
            validT = tx >= 1 & tx <= W & ty >= 1 & ty <= H;
            for i = 1:numel(validT)
                if validT(i)
                    overlayImg(ty(i), tx(i), :) = [255, 60, 60];
                end
            end

            % Crosshairs extending 14px
            for d = -14:14
                if abs(d) > 2
                    if (fx+d) >= 1 && (fx+d) <= W && fy >= 1 && fy <= H
                        overlayImg(fy, fx+d, :) = [255, 60, 60];
                    end
                    if fx >= 1 && fx <= W && (fy+d) >= 1 && (fy+d) <= H
                        overlayImg(fy+d, fx, :) = [255, 60, 60];
                    end
                end
            end
        end
    end

    if shouldDisplay
        figure('Name', 'Retinal Anatomical Map', 'NumberTitle', 'off');
        imshow(overlayImg);
        title('Retinal Anatomical Landmarks (Vessels, Optic Disc, Fovea)');
    end
end
