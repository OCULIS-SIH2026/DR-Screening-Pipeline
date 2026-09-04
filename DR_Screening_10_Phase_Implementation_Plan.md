# AI-Based Diabetic Retinopathy Screening Engine
## MATLAB/Simulink — 10-Phase Implementation Plan

### Project Goal

Build a MATLAB-based retinal image analysis **engine** for automated diabetic retinopathy (DR) screening in primary healthcare/telemedicine settings.

The engine should take a fundus photograph as input and produce:

- Image quality assessment
- Enhanced/normalized retinal image when appropriate
- Retinal structure and lesion evidence
- DR severity prediction from Level 0–4 using the supplied CNN
- Grad-CAM explainability
- Confidence/uncertainty information
- Referable DR decision
- Annotated screening report for ophthalmologist review

> **Important:** Another team member may train/fine-tune the CNN. This plan treats that CNN as an external model that your engine consumes through a defined interface.

---

# Overall Pipeline

```text
Fundus Image
     │
     ▼
[Phase 1] Input & Data Interface
     │
     ▼
[Phase 2] Image Quality Assessment
     │
     ├── Poor ───────► Recapture / Reject
     │
     ▼
[Phase 3] Image Enhancement
     │
     ▼
[Phase 4] Retinal Structure Analysis
     │
     ▼
[Phase 5] Lesion Detection / Evidence Extraction
     │
     ▼
[Phase 6] CNN Inference Interface
     │
     ▼
[Phase 7] Explainability + Grad-CAM
     │
     ▼
[Phase 8] Confidence + Clinical Decision Logic
     │
     ▼
[Phase 9] Automated Screening Report
     │
     ▼
[Phase 10] Simulink Workflow + System Validation
```

---

# Phase 1 — Input and Data Interface

## Objective

Create the basic engine that can reliably accept a fundus image and pass it through the system.

## Tasks

1. Accept common image formats such as JPG/PNG.
2. Convert images to a consistent representation.
3. Handle RGB/grayscale input correctly.
4. Resize images according to the CNN's required input size.
5. Store metadata such as:
   - Image ID
   - Original dimensions
   - Acquisition information, if available
6. Create a standardized internal image structure.

Example MATLAB structure:

```matlab
sample.image = img;
sample.originalSize = size(img);
sample.imageID = "patient_001";
sample.quality = [];
sample.enhancedImage = [];
sample.prediction = [];
sample.confidence = [];
sample.gradCAM = [];
sample.lesionEvidence = [];
```

## Deliverable

A MATLAB function such as:

```matlab
sample = loadFundusImage("fundus.jpg");
```

that produces a clean internal representation.

## Completion Criteria

- Images load correctly.
- Different image dimensions are handled.
- RGB/grayscale cases work.
- The same preprocessing convention can later be used by the CNN.

---

# Phase 2 — Image Quality Assessment

## Objective

Determine whether the photograph is good enough for reliable automated screening.

A major project requirement is handling poor-quality images from portable/field fundus cameras.

## Quality Factors

Measure at least:

### 1. Focus / Sharpness

Use measures such as:

- Variance of Laplacian
- Gradient magnitude
- Edge strength

A very blurry image should be rejected.

### 2. Brightness / Illumination

Detect:

- Very dark images
- Overexposed images
- Strong illumination gradients

### 3. Contrast

Measure whether retinal structures have sufficient contrast.

### 4. Field of View

Determine whether enough of the retina is visible.

Possible checks:

- Circular retinal field detection
- Retinal area percentage
- Black-border percentage

## Quality Decision

Create three states:

```text
GOOD
BORDERLINE
RECAPTURE
```

Example:

```text
Quality Score >= 0.75 → GOOD
0.50–0.75           → BORDERLINE
< 0.50              → RECAPTURE
```

These thresholds are placeholders and must eventually be validated.

## Deliverable

```matlab
[result, metrics] = assessImageQuality(img);
```

Example output:

```text
Quality: BORDERLINE

Sharpness: 0.62
Brightness: 0.81
Contrast: 0.71
FOV: 0.90
Overall Score: 0.76
```

## Completion Criteria

The engine can automatically identify obviously unusable images and provide a reason.

---

# Phase 3 — Image Enhancement and Normalization

## Objective

Improve borderline-but-recoverable images without creating artificial retinal lesions.

## Processing Pipeline

Recommended starting pipeline:

```text
Input
  ↓
Illumination normalization
  ↓
CLAHE
  ↓
Denoising
  ↓
Intensity normalization
  ↓
Enhanced image
```

## Techniques

### CLAHE

Contrast Limited Adaptive Histogram Equalization.

Useful for enhancing local retinal structures.

### Illumination Normalization

Reduce uneven lighting caused by the fundus camera.

### Denoising

Possible techniques:

- Median filtering
- Gaussian filtering
- Bilateral filtering

Do not over-smooth because tiny lesions such as microaneurysms can be lost.

## Important Rule

Do **not** automatically enhance every image.

Use:

```text
GOOD → usually preserve original + optional normalization
BORDERLINE → enhance
RECAPTURE → do not attempt to rescue aggressively
```

## Deliverable

```matlab
enhanced = enhanceFundusImage(img);
```

Also save:

- Original image
- Enhanced image
- Enhancement parameters

## Completion Criteria

You can visually compare original vs enhanced images and verify that retinal structures remain intact.

---

# Phase 4 — Retinal Structure Analysis

## Objective

Identify important anatomical structures that provide context for DR analysis.

## Structures

### Optic Disc

Locate the optic disc.

Possible approaches:

- Bright-region detection
- Circular/elliptical detection
- Deep-learning segmentation/detection

### Fovea

Estimate the foveal location relative to the optic disc.

The fovea is typically located temporal to the optic disc.

### Blood Vessels

Segment the retinal vascular network.

Possible starting methods:

- Green-channel extraction
- Morphological filtering
- Matched filters
- Frangi vesselness
- Deep-learning segmentation

## Output

Produce masks/coordinates:

```text
Optic Disc → bounding box / center
Fovea      → estimated coordinate
Vessels    → binary vessel mask
```

## Deliverable

A visualization:

```text
Original Fundus
       +
Optic Disc Marker
       +
Fovea Marker
       +
Vessel Mask
```

## Dataset Requirement

APTOS is mainly a DR grading dataset. It does not provide the complete pixel-level annotations needed for all these segmentation tasks.

For vessel segmentation, use an appropriate annotated retinal vessel dataset such as DRIVE/STARE/CHASE_DB1 or another validated dataset.

## Completion Criteria

An image can be converted into a basic anatomical map.

---

# Phase 5 — Lesion Detection and Clinical Evidence

## Objective

Identify retinal abnormalities associated with DR.

Target evidence:

- Microaneurysms
- Hemorrhages
- Exudates
- Neovascularization

## 5.1 Microaneurysms

Small red/dark circular lesions.

Challenge:

They are tiny and easily confused with noise or vessels.

Possible pipeline:

```text
Green channel
   ↓
Contrast enhancement
   ↓
Candidate detection
   ↓
Morphological filtering
   ↓
Candidate classification
```

This is one of the hardest components.

## 5.2 Hemorrhages

Typically larger/darker red regions.

Use:

- Color/intensity analysis
- Morphology
- Connected components
- CNN/object detection if available

## 5.3 Exudates

Bright/yellowish retinal lesions.

Possible pipeline:

```text
Color/intensity threshold
       ↓
Morphological cleanup
       ↓
Optic-disc removal
       ↓
Connected components
       ↓
Exudate candidates
```

Removing the optic disc is important because it is naturally very bright and can be falsely detected as an exudate.

## 5.4 Neovascularization

Abnormal new vessel growth.

This is substantially harder than basic vessel segmentation and may require specialized datasets/models.

## Deliverable

Generate lesion candidates:

```matlab
evidence.microaneurysms
evidence.hemorrhages
evidence.exudates
evidence.neovascularization
```

and overlay them on the fundus image.

## Critical Warning

Do not call a detected region a **confirmed clinical lesion** unless the method has been validated against appropriate ground-truth annotations.

For early prototypes, call them:

> "lesion candidates" or "supporting evidence."

---

# Phase 6 — CNN Inference Integration

## Objective

Connect your engine to the CNN trained/fine-tuned by the other team member.

You are not responsible for retraining the model if another teammate owns that component.

## Define a Model Contract

Before integration, obtain from the CNN developer:

### Input

- Required image size
- RGB/grayscale
- Normalization method
- Mean/std values
- Any cropping procedure

Example:

```text
224 × 224 × 3
RGB
ImageNet normalization
```

### Output

Five probabilities:

```text
Class 0 → No DR
Class 1 → Mild
Class 2 → Moderate
Class 3 → Severe
Class 4 → Proliferative
```

### Model Information

Also obtain:

- MATLAB model format
- Network architecture
- Best convolutional layer
- Classification layer
- Expected preprocessing
- Validation/test metrics

## Inference

Your engine should expose something like:

```matlab
prediction = runDRModel(model, img);
```

Output:

```text
DR Level: 2
Probabilities:
0 → 0.02
1 → 0.08
2 → 0.72
3 → 0.15
4 → 0.03
```

## Completion Criteria

Your engine can take any accepted fundus image and obtain a DR prediction from the supplied model.

---

# Phase 7 — Explainability and Grad-CAM

## Objective

Show **why the CNN produced its prediction**.

This is essential because the project specifically requires explainability.

## Grad-CAM Pipeline

```text
Fundus Image
     ↓
CNN
     ↓
Target DR class
     ↓
Gradients
     ↓
Convolutional feature maps
     ↓
Grad-CAM heatmap
     ↓
Overlay on retina
```

The heatmap should highlight image regions contributing strongly to the selected prediction.

## Output

Create:

```text
Original Image
Enhanced Image
Grad-CAM Heatmap
Grad-CAM Overlay
```

Example interpretation:

```text
Prediction: Moderate DR

Grad-CAM:
High activation around regions containing suspected retinal lesions.
```

## Important Distinction

Grad-CAM is an **explainability method**, not proof that the highlighted region is a clinically confirmed lesion.

Therefore combine:

```text
CNN prediction
+
Grad-CAM
+
Independent lesion evidence
```

rather than treating Grad-CAM alone as lesion detection.

## Completion Criteria

For every prediction, the engine can generate a readable Grad-CAM overlay.

---

# Phase 8 — Confidence, Referable DR, and Decision Logic

## Objective

Convert raw CNN output into a clinically useful screening decision.

## Five-Level Prediction

The model predicts:

```text
0 → No DR
1 → Mild NPDR
2 → Moderate NPDR
3 → Severe NPDR
4 → Proliferative DR
```

## Referable DR

For this project:

```text
Level 0, 1 → Non-referable
Level 2, 3, 4 → Referable
```

So:

```matlab
referable = predictedClass >= 2;
```

## Confidence

Store:

```text
Predicted class
Class probability
Maximum probability
Probability distribution
```

Example:

```text
Prediction: Level 3
Confidence: 91%
Referable: YES
```

## Calibration

Raw neural-network probabilities are not automatically reliable confidence estimates.

If time permits, use calibration such as:

- Temperature scaling
- Reliability diagrams
- Expected Calibration Error

## Uncertainty Rule

Example concept:

```text
High confidence + good quality
        ↓
Automated screening result

Low confidence OR poor/borderline quality
        ↓
Human review
```

The exact thresholds must be experimentally validated.

## Target Metrics

For referable DR:

- Sensitivity > 90%
- Specificity > 85%

Also measure:

- Precision
- F1-score
- ROC-AUC
- Confusion matrix
- Per-class sensitivity/recall

Do not rely on accuracy alone.

## Completion Criteria

The engine produces a clear:

```text
DR Grade
Referable / Non-referable
Confidence
Human-review flag
```

---

# Phase 9 — Automated Clinical-Style Report

## Objective

Combine every component into one output that an ophthalmologist can quickly review.

## Report Should Contain

### Patient/Image Information

```text
Image ID
Image quality
Processing status
```

### AI Result

```text
DR Grade: Moderate
Referable DR: YES
Confidence: 91%
```

### Evidence

```text
Suspected microaneurysm candidates
Suspected hemorrhage candidates
Suspected exudate candidates
```

### Visualizations

Include:

1. Original fundus
2. Enhanced fundus
3. Vessel segmentation
4. Lesion overlay
5. Grad-CAM overlay

### Recommendation

For example:

```text
REFER FOR OPHTHALMOLOGIST REVIEW
```

Avoid claiming a definitive diagnosis.

## Example Report

```text
========================================
DIABETIC RETINOPATHY SCREENING REPORT
========================================

Image Quality: GOOD

Predicted DR Level: 2
Classification: Moderate DR

Referable DR: YES
Model Confidence: 91%

Supporting Evidence:
- Microaneurysm candidates detected
- Hemorrhage candidates detected
- Abnormal regions highlighted by Grad-CAM

Recommendation:
OPHTHALMOLOGIST REVIEW REQUIRED

========================================
```

## Design Goal

An ophthalmologist should be able to understand the result in under 30 seconds, as required by the problem statement.

## Completion Criteria

One MATLAB command should generate the complete screening result.

---

# Phase 10 — Simulink Workflow + System Validation

This phase turns the image-analysis prototype into a system-level deployment model.

## Part A — Simulink Workflow

Model:

```text
Patient Arrival
      ↓
Image Acquisition
      ↓
Quality Assessment
      ↓
AI Processing
      ↓
Human Review
      ↓
Final Decision
```

## Parameters to Simulate

### Patient Volume

Example:

```text
100,000+ patients/year
```

### Acquisition Rate

```text
Patients/hour
Images/day
```

### AI Processing

```text
Inference time/image
Images/hour
Number of AI processing nodes
```

### Network

```text
Image size
Bandwidth
Upload latency
```

### Human Review

```text
Review time/image
Ophthalmologists available
Images/reviewer/hour
```

## Questions the Simulation Should Answer

- How many patients can the system process?
- Where is the bottleneck?
- How many AI processing nodes are needed?
- How many ophthalmologists are needed?
- What happens when image quality causes recapture?
- How does bandwidth affect throughput?
- What happens during peak patient load?

## Example

```text
100,000 patients/year
        ↓
Image acquisition
        ↓
Quality rejection rate
        ↓
AI throughput
        ↓
Referable cases
        ↓
Ophthalmologist workload
        ↓
Queue / waiting time
```

---

# Final Integration

After completing the ten phases, combine them into one main function.

Example:

```matlab
result = screenFundusImage("patient_001.jpg", model);
```

Internally:

```text
screenFundusImage()
        │
        ├── loadFundusImage()
        │
        ├── assessImageQuality()
        │
        ├── enhanceFundusImage()
        │
        ├── analyzeRetinalStructures()
        │
        ├── detectLesionCandidates()
        │
        ├── runDRModel()
        │
        ├── generateGradCAM()
        │
        ├── calculateConfidence()
        │
        ├── determineReferral()
        │
        └── generateScreeningReport()
```

---

# Recommended Development Order

Do not attempt all ten phases simultaneously.

Use this order:

| Phase | Priority | Difficulty | Main Output |
|---|---:|---:|---|
| 1. Input | Very High | Low | Reliable image input |
| 2. Quality Assessment | Very High | Medium | Good/Borderline/Recapture |
| 3. Enhancement | High | Low-Medium | Improved image |
| 4. Structure Analysis | High | Medium-High | Disc/fovea/vessel maps |
| 5. Lesion Analysis | High | High | Lesion candidates |
| 6. CNN Integration | Very High | Medium | DR 0–4 prediction |
| 7. Grad-CAM | Very High | Medium | Explainability map |
| 8. Decision Logic | Very High | Medium | Referable + confidence |
| 9. Report | High | Medium | Complete screening report |
| 10. Simulink + Validation | Final | High | Deployment simulation |

---

# Milestones

## Milestone 1 — Basic Engine

Complete:

- Phase 1
- Phase 2
- Phase 3

Input:

```text
fundus.jpg
```

Output:

```text
Quality = GOOD
Enhanced image = generated
```

---

## Milestone 2 — CNN Integration

Complete:

- Phase 6
- Phase 8

Input:

```text
fundus.jpg
```

Output:

```text
DR Level = 2
Confidence = 91%
Referable = YES
```

This is the first major working prototype.

---

## Milestone 3 — Explainable AI

Complete:

- Phase 7
- Phase 9

Output:

```text
DR Level
Confidence
Referable status
Grad-CAM
Image-quality result
Automated report
```

At this point you have a useful end-to-end screening engine.

---

## Milestone 4 — Clinical Evidence

Complete:

- Phase 4
- Phase 5

Add:

- Optic disc
- Fovea
- Vessels
- Microaneurysm candidates
- Hemorrhage candidates
- Exudate candidates
- Neovascularization analysis where feasible

This makes the system more clinically interpretable.

---

## Milestone 5 — System-Level Simulation

Complete:

- Phase 10

Connect the engine's measured processing times and rejection/referral rates to Simulink.

Final output:

```text
Patient volume
↓
Acquisition
↓
Image quality
↓
AI processing
↓
Referral
↓
Ophthalmologist workload
↓
System capacity
```

---

# Team Interface

If another teammate is training the CNN, agree on this contract early.

## CNN Developer Must Provide

```text
1. Model file
2. Input dimensions
3. Input preprocessing
4. Class mapping
5. Output probability format
6. Best Grad-CAM layer
7. Validation/test metrics
8. Required MATLAB toolbox/version
```

## Your Engine Provides

```text
1. Image input
2. Quality assessment
3. Enhancement
4. Retinal analysis
5. CNN inference wrapper
6. Grad-CAM
7. Confidence/decision logic
8. Evidence visualization
9. Screening report
10. Simulink integration
```

---

# Suggested MATLAB Project Structure

```text
DR_Screening/
│
├── main/
│   └── screenFundusImage.m
│
├── input/
│   └── loadFundusImage.m
│
├── quality/
│   ├── assessImageQuality.m
│   ├── calculateSharpness.m
│   ├── assessBrightness.m
│   ├── assessContrast.m
│   └── assessFOV.m
│
├── enhancement/
│   ├── enhanceFundusImage.m
│   ├── applyCLAHE.m
│   ├── normalizeIllumination.m
│   └── denoiseFundus.m
│
├── anatomy/
│   ├── locateOpticDisc.m
│   ├── locateFovea.m
│   └── segmentVessels.m
│
├── lesions/
│   ├── detectMicroaneurysms.m
│   ├── detectHemorrhages.m
│   ├── detectExudates.m
│   └── detectNeovascularization.m
│
├── model/
│   ├── loadDRModel.m
│   ├── preprocessForModel.m
│   └── runDRModel.m
│
├── explainability/
│   └── generateGradCAM.m
│
├── decision/
│   ├── calibrateConfidence.m
│   └── determineReferral.m
│
├── report/
│   └── generateScreeningReport.m
│
├── simulink/
│   └── DR_Screening_System.slx
│
├── datasets/
│
└── tests/
    ├── testQuality.m
    ├── testEnhancement.m
    ├── testModel.m
    └── testPipeline.m
```

---

# Definition of Done

The project is not "done" merely because the CNN produces a DR class.

A strong prototype should be able to execute:

```text
FUNDUS IMAGE
     ↓
QUALITY CHECK
     ↓
ENHANCEMENT
     ↓
RETINAL ANALYSIS
     ↓
CNN DR GRADING
     ↓
GRAD-CAM
     ↓
LESION EVIDENCE
     ↓
CONFIDENCE
     ↓
REFERABLE / NON-REFERABLE
     ↓
ANNOTATED REPORT
```

and the Simulink model should then demonstrate whether this pipeline can realistically support the target screening workload.

## Most Important Rule

**Build incrementally.**

Do not start with the full clinical system.

Start with:

```text
Image → Quality → CNN → DR Level
```

Then add:

```text
→ Grad-CAM
→ Confidence
→ Report
→ Anatomy
→ Lesions
→ Simulink
```

This gives you a working system at every major stage and prevents the project from becoming stuck on the hardest components first.
