## Milestone 1 — Basic Engine (Phases 1, 2, & 3)

This repository implements an automated, clinical-grade diabetic retinopathy (DR) screening pipeline in MATLAB.

### Directory Structure

```text
DR Screening Pipeline/
├── setup_environment.m              # Initializes MATLAB paths for all modules
├── main/
│   └── demoMilestone1.m             # End-to-end demonstration of Milestone 1
├── input/
│   ├── loadFundusImage.m            # Primary image loader & preprocessor
│   ├── createSampleStruct.m         # Standardized internal struct generator
│   └── validateFundusInput.m        # File existence & format validator
├── quality/
│   ├── assessImageQuality.m         # Master IQA coordinator & decision logic
│   ├── assessFOV.m                  # Retinal mask extraction & FOV scoring
│   ├── calculateSharpness.m         # Variance of Laplacian & Sobel gradient
│   ├── assessBrightness.m           # Underexposure/overexposure & uniformity
│   └── assessContrast.m             # RMS & dynamic range structural contrast
├── enhancement/
│   ├── enhanceFundusImage.m         # Master enhancement coordinator & gate
│   ├── applyCLAHE.m                 # CLAHE in CIE L*a*b* color space
│   ├── normalizeIllumination.m      # Background illumination field correction
│   └── denoiseFundus.m              # Edge-preserving bilateral/median denoising
├── anatomy/
│   ├── analyzeRetinalStructures.m   # Master anatomical structure coordinator
│   ├── locateOpticDisc.m            # Optic disc detection, radius & segmentation
│   ├── segmentVessels.m             # Multi-scale morphological vessel segmentation
│   ├── locateFovea.m                # Macular center localization & laterality
│   └── visualizeAnatomy.m           # High-contrast clinical overlay generator
├── tests/
│   ├── testPhase1.m                 # Unit test suite for Phase 1
│   ├── testPhase2.m                 # Unit test suite for Phase 2
│   ├── testPhase3.m                 # Unit test suite for Phase 3
│   ├── testPhase4.m                 # Unit test suite for Phase 4
│   └── generateSyntheticFundus.m    # Realistic synthetic fundus test generator
├── utils/
│   ├── getConfig.m                  # Dynamic configuration provider (no hardcoded paths)
│   └── loadEnv.m                    # .env parser and environment injector
├── .env.example                     # Environment template (paths, model weights, thresholds)
└── README.md
```

---

### Configuration & Environment (`.env`)

To prevent hardcoding local directory paths or model locations:

1. Copy the environment template:
   ```bash
   cp .env.example .env
   ```
2. Adjust your local paths and parameters in `.env`:
   ```ini
   DATASET_DIR=datasets/raw
   MODEL_PATH=model/weights/dr_screening_model.mat
   TARGET_IMAGE_HEIGHT=224
   TARGET_IMAGE_WIDTH=224
   QUALITY_GOOD_THRESH=0.75
   ```
3. In MATLAB, all modules dynamically query configurations using `getConfig()`:
   ```matlab
   cfg = getConfig();
   disp(cfg.TARGET_SIZE); % [224, 224]
   disp(cfg.MODEL_PATH);  % 'model/weights/dr_screening_model.mat'
   ```
   *Note: `.env` is automatically ignored by Git so your local file paths are never committed.*

---

### Quick Start (MATLAB Online or Desktop)

1. **Initialize the Environment**:
   ```matlab
   setup_environment;
   ```

2. **Run All Unit Tests**:
   ```matlab
   testPhase1;
   testPhase2;
   testPhase3;
   ```

3. **Run End-to-End Milestone 1 Demo**:
   ```matlab
   demoMilestone1;
   ```

4. **Single-Patient Pipeline Usage**:
   ```matlab
   % 1. Ingest image (standardizes color space and target dimensions)
   sample = loadFundusImage("fundus.jpg", 'TargetSize', [224, 224]);

   % 2. Quality Assessment (GOOD, BORDERLINE, RECAPTURE)
   sample = assessImageQuality(sample);

   % 3. Selective Enhancement (runs CLAHE + Illumination Norm ONLY on BORDERLINE)
   sample = enhanceFundusImage(sample);

   % 4. Retinal Structure Analysis (Optic Disc, Vessels, Fovea & Clinical Overlay)
   sample = analyzeRetinalStructures(sample);

   % Inspect anatomical landmarks
   disp(sample.anatomy.opticDisc.center); % [x, y]
   disp(sample.anatomy.fovea.center);     % [x, y]
   disp(sample.anatomy.vessels.density);  % e.g. 0.114 (11.4% vascular coverage)
   imshow(sample.anatomy.overlay);        % View colored clinical anatomical overlay
   ```

---

### Selective Enhancement Rules (Phase 3)

In accordance with clinical protocol:
- **`GOOD` images**: Left untouched (`applied = false`). Aggressive enhancement is avoided so artificial microaneurysms or bleeding artifacts are not hallucinated.
- **`BORDERLINE` images**: Recoverable cases undergo illumination field normalization, CIE $L^*a^*b^*$ CLAHE, and edge-preserving bilateral denoising to boost vessel and lesion contrast.
- **`RECAPTURE` images**: Severely blurred or blacked-out images are not processed further (`applied = false`) and require physical re-imaging.

---

### Quality Assessment Logic (Phase 2)

| Factor | Metric | Role | Hard Fail Threshold |
|---|---|---|---|
| **Sharpness** (35%) | Variance of Laplacian + Sobel | Focus & blur detection | Score < 0.28 (Severe blur) |
| **Brightness** (25%) | Mean luminance + uniformity | Over/underexposure | Underexposed > 45% or Overexposed > 30% |
| **Contrast** (20%) | RMS contrast + 90% dynamic range | Vessel & lesion visibility | — |
| **FOV** (20%) | Retinal area ratio + circularity | Complete retinal view | Retinal area < 25% |

- **`GOOD`** (Score $\ge 0.75$, no hard fails): Image proceeds directly to feature analysis and CNN inference.
- **`BORDERLINE`** ($0.50 \le \text{Score} < 0.75$, no hard fails): Recoverable image; passed to **Phase 3 (Image Enhancement)**.
- **`RECAPTURE`** (Score $< 0.50$ or hard fail): Unusable; immediate alert for technician to retake the fundus photograph.

---

### Standard `sample` Schema

The pipeline uses a unified MATLAB struct schema across all 10 phases:

| Field | Type | Description |
|---|---|---|
| `imageID` | `string` | Unique image/patient identifier |
| `filePath` | `string` | Source file location |
| `originalImage` | `uint8` | Untouched original RGB matrix |
| `originalSize` | `1x3 double` | Original dimensions `[H, W, C]` |
| `image` | `uint8` | Standardized RGB matrix (target size) |
| `currentSize` | `1x3 double` | Current dimensions `[H, W, C]` |
| `metadata` | `struct` | File size, format, timestamps, resizing info |
| `quality` | `struct` | *Phase 2 placeholder (status, metrics, overall score)* |
| `enhancedImage` | `uint8` | *Phase 3 placeholder (enhanced RGB if borderline)* |
| `anatomy` | `struct` | *Phase 4 placeholder (optic disc, fovea, vessels)* |
| `lesionEvidence`| `struct` | *Phase 5 placeholder (microaneurysms, hemorrhages, exudates)* |
| `prediction` | `struct` | *Phase 6 placeholder (DR class 0-4, probabilities)* |
| `gradCAM` | `struct` | *Phase 7 placeholder (heatmap, overlay)* |
| `decision` | `struct` | *Phase 8 placeholder (referable: true/false, confidence)* |
| `report` | `struct` | *Phase 9 placeholder (clinical summary report)* |
