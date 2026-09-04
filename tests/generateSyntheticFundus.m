function img = generateSyntheticFundus(H, W, varargin)
% GENERATESYNTHETICFUNDUS Generates a synthetic fundus image for testing.
%
% Usage:
%   img = generateSyntheticFundus(H, W)
%   img = generateSyntheticFundus(H, W, 'Quality', 'good', 'ColorSpace', 'rgb')
%
% Options:
%   'Quality'    - 'good', 'blurry', 'underexposed', 'overexposed' (default: 'good')
%   'ColorSpace' - 'rgb', 'grayscale', 'rgba' (default: 'rgb')

    p = inputParser;
    addRequired(p, 'H', @isnumeric);
    addRequired(p, 'W', @isnumeric);
    addParameter(p, 'Quality', 'good', @ischar);
    addParameter(p, 'ColorSpace', 'rgb', @ischar);
    parse(p, H, W, varargin{:});

    quality = lower(p.Results.Quality);
    colorSpace = lower(p.Results.ColorSpace);

    % 1. Create retinal circular mask
    [X, Y] = meshgrid(1:W, 1:H);
    centerX = W / 2;
    centerY = H / 2;
    radius = min(centerX, centerY) * 0.90;
    dist = sqrt((X - centerX).^2 + (Y - centerY).^2);
    retinaMask = dist <= radius;

    % 2. Base orange-red retinal background
    R = zeros(H, W);
    G = zeros(H, W);
    B = zeros(H, W);

    % Gradual shading towards periphery
    normDist = dist / radius;
    shading = max(0, 1 - 0.4 * (normDist.^2));

    R(retinaMask) = 180 * shading(retinaMask) + 20 * randn(sum(retinaMask(:)), 1);
    G(retinaMask) = 75  * shading(retinaMask) + 15 * randn(sum(retinaMask(:)), 1);
    B(retinaMask) = 25  * shading(retinaMask) + 10 * randn(sum(retinaMask(:)), 1);

    % 3. Add Optic Disc (bright yellow circle nasal to center)
    odX = centerX + radius * 0.45;
    odY = centerY;
    odRadius = radius * 0.15;
    odMask = sqrt((X - odX).^2 + (Y - odY).^2) <= odRadius & retinaMask;

    R(odMask) = 240 + 10 * randn(sum(odMask(:)), 1);
    G(odMask) = 220 + 10 * randn(sum(odMask(:)), 1);
    B(odMask) = 140 + 10 * randn(sum(odMask(:)), 1);

    % 4. Add Fovea (dark macula region temporal to center)
    foveaX = centerX - radius * 0.25;
    foveaY = centerY;
    foveaRadius = radius * 0.12;
    foveaMask = sqrt((X - foveaX).^2 + (Y - foveaY).^2) <= foveaRadius & retinaMask;
    R(foveaMask) = R(foveaMask) * 0.65;
    G(foveaMask) = G(foveaMask) * 0.65;
    B(foveaMask) = B(foveaMask) * 0.65;

    % 5. Add Simulated Retinal Vascular Tree (superior & inferior arcades)
    vesselGrid = false(H, W);
    t = linspace(0, 1, 300);
    
    % Arcades arching from Optic Disc around the fovea
    % Superior temporal arcade:
    arc1X = odX - (odX - centerX * 0.3) * t;
    arc1Y = odY - (radius * 0.60) * sin(pi * t);
    % Inferior temporal arcade:
    arc2X = odX - (odX - centerX * 0.3) * t;
    arc2Y = odY + (radius * 0.60) * sin(pi * t);
    % Nasal branches:
    arc3X = odX + (radius * 0.35) * t;
    arc3Y = odY - (radius * 0.30) * sin(pi * t);
    arc4X = odX + (radius * 0.35) * t;
    arc4Y = odY + (radius * 0.30) * sin(pi * t);

    arcades = {[arc1X; arc1Y], [arc2X; arc2Y], [arc3X; arc3Y], [arc4X; arc4Y]};
    for a = 1:numel(arcades)
        pts = arcades{a};
        for ptIdx = 1:size(pts, 2)
            px = round(pts(1, ptIdx));
            py = round(pts(2, ptIdx));
            if px >= 2 && px <= (W-1) && py >= 2 && py <= (H-1) && retinaMask(py, px)
                vesselGrid(py-1:py+1, px-1:px+1) = true;
            end
        end
    end

    % Vessels are darker, especially in green channel (strong absorption)
    R(vesselGrid) = R(vesselGrid) * 0.45;
    G(vesselGrid) = G(vesselGrid) * 0.30;
    B(vesselGrid) = B(vesselGrid) * 0.35;

    % 5. Clip and cast to uint8
    R = uint8(max(0, min(255, R)));
    G = uint8(max(0, min(255, G)));
    B = uint8(max(0, min(255, B)));
    rgb = cat(3, R, G, B);

    % 6. Apply quality degradation if specified
    switch quality
        case 'blurry'
            hBlur = fspecial('gaussian', [25, 25], 8);
            rgb = imfilter(rgb, hBlur);
        case 'underexposed'
            rgb = uint8(double(rgb) * 0.25);
        case 'overexposed'
            rgb = uint8(min(255, double(rgb) * 2.2));
    end

    % 7. Format color space
    switch colorSpace
        case 'grayscale'
            img = rgb2gray(rgb);
        case 'rgba'
            alpha = uint8(retinaMask * 255);
            img = cat(3, rgb, alpha);
        otherwise
            img = rgb;
    end
end
