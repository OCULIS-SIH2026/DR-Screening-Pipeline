function [claheImg, L_enhanced] = applyCLAHE(img, retinaMask, varargin)
% APPLYCLAHE Contrast Limited Adaptive Histogram Equalization in Lab color space.
%
% Enhances local micro-structures (vessels, hemorrhages, exudates) without
% altering retinal color balance or amplifying background noise.
%
% Usage:
%   claheImg = applyCLAHE(img)
%   claheImg = applyCLAHE(img, retinaMask)
%   claheImg = applyCLAHE(img, retinaMask, 'ClipLimit', 0.02, 'Distribution', 'rayleigh')
%
% Inputs:
%   img        - RGB fundus image (uint8).
%   retinaMask - (Optional) Logical mask of the retinal area.
%
% Name-Value Parameters:
%   'ClipLimit'    - Contrast factor for adapthisteq in [0, 1] (default: 0.02).
%   'Distribution' - 'rayleigh', 'uniform', or 'exponential' (default: 'rayleigh').
%   'NumTiles'     - [Rows, Cols] grid size for contextual tiles (default: [8, 8]).
%
% Outputs:
%   claheImg   - Contrast-enhanced RGB fundus image (uint8).
%   L_enhanced - Enhanced luminance channel in [0, 100].
%
% Reference:
%   Phase 3: Image Enhancement and Normalization

    p = inputParser;
    addRequired(p, 'img');
    addOptional(p, 'retinaMask', [], @(x) isempty(x) || islogical(x) || isnumeric(x));
    addParameter(p, 'ClipLimit', 0.02, @(x) isnumeric(x) && x > 0 && x <= 1);
    addParameter(p, 'Distribution', 'rayleigh', @(x) ischar(x) || isstring(x));
    addParameter(p, 'NumTiles', [8, 8], @(x) isnumeric(x) && numel(x) == 2);
    parse(p, img, retinaMask, varargin{:});

    mask = p.Results.retinaMask;
    if isempty(mask)
        [~, ~, mask] = assessFOV(img);
    else
        mask = logical(mask);
    end

    clipLimit = p.Results.ClipLimit;
    distrib   = char(p.Results.Distribution);
    numTiles  = p.Results.NumTiles;

    % 1. Convert RGB to CIE L*a*b* space
    % L* represents luminance [0, 100], while a* and b* encode chromaticity.
    labImg = rgb2lab(img);
    L = labImg(:, :, 1);
    a = labImg(:, :, 2);
    b = labImg(:, :, 3);

    % 2. Normalize L* channel to [0, 1] for adapthisteq
    L_norm = L / 100.0;

    % 3. Apply CLAHE only within contextual retinal area
    % adapthisteq limits local contrast slope to prevent noise blooming
    L_eq = adapthisteq(L_norm, ...
        'ClipLimit', clipLimit, ...
        'Distribution', distrib, ...
        'NumTiles', numTiles);

    % 4. Rescale back to [0, 100]
    L_enhanced = L_eq * 100.0;

    % 5. Recombine channels and convert back to RGB
    enhancedLab = cat(3, L_enhanced, a, b);
    rgbDbl = lab2rgb(enhancedLab);

    % 6. Reapply retinal mask to maintain pure black background perimeter
    claheImg = uint8(round(max(0, min(1, rgbDbl)) * 255));
    for c = 1:size(claheImg, 3)
        ch = claheImg(:, :, c);
        ch(~mask) = 0;
        claheImg(:, :, c) = ch;
    end
end
