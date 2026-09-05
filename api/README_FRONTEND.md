# Frontend Developer Guide — OCULIS DR Screening API

Welcome! This guide explains how to connect your Web UI (React, Next.js, Vue, or Vanilla JS) to the **AI-Based Diabetic Retinopathy (DR) Screening Engine**.

---

## 1. Quick Start (No Python Setup Needed First!)

You can start developing the frontend **immediately** without waiting for PyTorch or backend setup:
1. Copy the sample response from `mock_response.json` into your frontend state or mock service worker.
2. Or run the backend and fetch `GET http://localhost:8000/api/mock` to get live mock data with pre-rendered base64 fundus and Grad-CAM images.

---

## 2. Running the Backend Server

When you are ready to run the backend locally:
```bash
# 1. Navigate to the api directory
cd api

# 2. (Optional) Install dependencies
pip install -r requirements.txt

# 3. Double-click run_api.bat OR run in terminal:
python -m uvicorn app:app --reload --port 8000
```
* **API Documentation (Swagger UI):** [`http://localhost:8000/docs`](http://localhost:8000/docs)
* **CORS:** Pre-configured with `allow_origins=["*"]`. You will **never** get CORS errors when developing on `localhost:3000`, `localhost:5173`, etc.

---

## 3. The Screening Endpoint

### `POST /api/screen`

Send the fundus image file as `multipart/form-data`.

#### Copy-Paste JavaScript (Fetch) Example
```javascript
async function screenFundusImage(imageFile, patientId = "") {
  const formData = new FormData();
  formData.append("image", imageFile);
  if (patientId) {
    formData.append("patient_id", patientId);
  }

  try {
    const res = await fetch("http://localhost:8000/api/screen", {
      method: "POST",
      body: formData,
    });

    if (!res.ok) {
      const errorData = await res.json();
      throw new Error(errorData.detail || "Screening failed");
    }

    const data = await res.json();
    return data;
  } catch (err) {
    console.error("Screening Error:", err);
    throw err;
  }
}
```

#### React Component Usage Example
```jsx
import React, { useState } from "react";

export function FundusUploader() {
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);

  async function handleFileChange(e) {
    const file = e.target.files[0];
    if (!file) return;

    setLoading(true);
    const data = await screenFundusImage(file);
    setResult(data);
    setLoading(false);
  }

  return (
    <div className="screening-dashboard">
      <input type="file" accept="image/*" onChange={handleFileChange} />

      {loading && <p>Analyzing fundus image...</p>}

      {result && (
        <div className="results-grid">
          {/* Quality Badge */}
          <div className={`badge badge-${result.quality.status.toLowerCase()}`}>
            Quality: {result.quality.status} (Score: {result.quality.overall_score})
          </div>

          {/* AI Prediction */}
          <h2>Prediction: {result.prediction.label} (Stage {result.prediction.stage})</h2>
          <p>Confidence: {(result.prediction.confidence * 100).toFixed(1)}%</p>

          {/* Clinical Triage Badge */}
          <div className={result.triage.is_referable ? "alert-danger" : "alert-success"}>
            <strong>{result.triage.referral_category}</strong>
            <p>{result.triage.recommendation}</p>
            <small>Urgency: {result.triage.urgency} ({result.triage.timeframe})</small>
          </div>

          {/* Visual Overlays (Render directly from Base64) */}
          <div className="image-comparison">
            <div>
              <h3>Original Photograph</h3>
              <img src={result.visuals.original_image} alt="Original Fundus" />
            </div>
            <div>
              <h3>CLAHE Enhanced</h3>
              <img src={result.visuals.enhanced_image} alt="Enhanced Fundus" />
            </div>
            <div>
              <h3>Grad-CAM Activation</h3>
              <img src={result.visuals.gradcam_overlay} alt="Grad-CAM Overlay" />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
```

---

## 4. Response Data Schema Explained

| Field | Type | Description |
| :--- | :--- | :--- |
| `status` | string | `"success"` or `"error"`. |
| `patient_id` | string | Patient identifier string. |
| `processing_time_ms` | number | Pipeline latency in milliseconds. |
| `quality.status` | string | `"Pass"`, `"Borderline"`, or `"Reject"`. |
| `quality.overall_score` | number | Quality grade from `0.0` to `1.0`. |
| `quality.metrics` | object | `{ sharpness, brightness, contrast, fov_valid }`. |
| `prediction.stage` | number | `0` (No DR) to `4` (Proliferative DR). |
| `prediction.label` | string | `"No DR"`, `"Mild NPDR"`, `"Moderate NPDR"`, `"Severe NPDR"`, or `"Proliferative DR"`. |
| `prediction.confidence` | number | Probability of top class (`0.0` to `1.0`). |
| `prediction.probabilities` | object | Key-value mapping of all 5 class probabilities. |
| `triage.is_referable` | boolean | `true` if Stage $\ge 2$ (requires ophthalmologist referral), `false` if Stage $\le 1$. |
| `triage.urgency` | string | Clinical triage urgency level (e.g. `"Routine Ophthalmology"`, `"Urgent"`). |
| `triage.timeframe` | string | Recommended clinic visit timeframe (e.g. `"Within 4 to 6 weeks"`). |
| `triage.recommendation` | string | Clinical action note for ophthalmologist or primary physician. |
| `visuals.original_image` | string | Base64 Data URI (`data:image/jpeg;base64,...`) of original uploaded image. |
| `visuals.enhanced_image` | string | Base64 Data URI of CLAHE-enhanced image. |
| `visuals.gradcam_overlay` | string | Base64 Data URI of Jet colormap Grad-CAM heatmap overlay. |

---

## 5. Medical UI/UX Design Guidelines

* **Grad-CAM Labeling:** In compliance with ophthalmology AI standards, label the heatmap as **"Model-Influential Regions"** or **"Grad-CAM Attention Map"**, *not* "AI Detected Lesions".
* **Referral Alert:** Highlight `triage.is_referable == true` with an amber/red clinical badge so primary health workers can immediately triage the patient.
