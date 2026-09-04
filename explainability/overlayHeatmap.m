function overlayImg = overlayHeatmap(img, heatmap, varargin)
% OVERLAYHEATMAP Blends a 2D activation heatmap with an RGB fundus photograph.
%
% Usage:
%   overlayImg = overlayHeatmap(img, heatmap)
%   overlayImg = overlayHeatmap(img, heatmap, 'Alpha', 0.40, 'RetinaMask', mask)
%
% Inputs:
%   img        - RGB fundus image (uint8) [H, W, 3].
%   heatmap    - 2D double matrix [H, W] normalized in [0.0, 1.0].
%
% Name-Value Parameters:
%   'Alpha'      - Heatmap blending weight in [0.0, 1.0] (default: 0.45).
%   'RetinaMask' - (Optional) Logical mask to confine heatmap inside retina.
%   'Colormap'   - 'jet' (default), 'turbo', or 'hot'.
%
% Outputs:
%   overlayImg   - RGB composite fundus image with heatmap overlay (uint8).
%
% Reference:
%   Phase 7: Explainability and Grad-CAM

    p = inputParser;
    addRequired(p, 'img');
    addRequired(p, 'heatmap', @isnumeric);
    addParameter(p, 'Alpha', 0.45, @(x) isnumeric(x) && x >= 0 && x <= 1);
    addParameter(p, 'RetinaMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
    addParameter(p, 'Colormap', 'jet', @(x) ischar(x) || isstring(x));
    parse(p, img, heatmap, varargin{:});

    alpha      = p.Results.Alpha;
    retinaMask = p.Results.RetinaMask;
    cmapChoice = lower(char(p.Results.Colormap));

    [H, W, ~] = size(img);

    % Ensure heatmap matches image size
    if size(heatmap, 1) ~= H || size(heatmap, 2) ~= W
        heatmap = imresize(heatmap, [H, W]);
    end

    % Normalize heatmap strictly to [0.0, 1.0]
    minVal = min(heatmap(:));
    maxVal = max(heatmap(:));
    if (maxVal - minVal) > 1e-6
        normHeatmap = (heatmap - minVal) / (maxVal - minVal);
    else
        normHeatmap = zeros(H, W);
    end

    if isempty(retinaMask)
        [~, ~, retinaMask] = assessFOV(img);
    else
        retinaMask = logical(retinaMask);
    end
    normHeatmap(~retinaMask) = 0;

    % 1. Map normalized heatmap to RGB using colormap
    numLevels = 256;
    switch cmapChoice
        case 'turbo'
            try
                cmap = turbo(numLevels);
            catch
                cmap = jet(numLevels);
            end
        case 'hot'
            cmap = hot(numLevels);
        otherwise
            cmap = jet(numLevels);
    end

    % Quantize heatmap values into colormap indices [1, 256]
    heatIdx = round(normHeatmap * (numLevels - 1)) + 1;
    heatIdx = max(1, min(numLevels, heatIdx));

    coloredHeatmap = zeros(H, W, 3);
    for c = 1:3
        channelLut = cmap(:, c);
        coloredHeatmap(:, :, c) = channelLut(heatIdx);
    end
    coloredHeatmap = uint8(round(coloredHeatmap * 255));

    % 2. Alpha blending: overlay = (1 - alpha)*img + alpha*coloredHeatmap
    imgDbl = double(img);
    heatDbl = double(coloredHeatmap);

    overlayDbl = zeros(H, W, 3);
    for c = 1:3
        imgCh  = imgDbl(:, :, c);
        heatCh = heatDbl(:, :, c);
        
        % Blend inside retina
        blended = (1.0 - alpha) * imgCh + alpha * heatCh;
        
        % Outside retina, keep original background
        blended(~retinaMask) = imgCh(~retinaMask);
        overlayDbl(:, :, c) = blended;
    end

    overlayImg = uint8(max(0, min(255, round(overlayDbl))));
end
