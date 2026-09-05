"""
DR Screening REST API Service
=============================
FastAPI backend for automated Diabetic Retinopathy screening and explainability.
Exposes REST endpoints for the Frontend Developer.
"""

import os
import io
import time
from typing import Optional
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from PIL import Image

from pipeline_bridge import (
    ScreeningModelRunner,
    assess_image_quality,
    enhance_fundus_image,
    make_clinical_triage,
    pil_to_base64,
    CLASS_NAMES,
    CLASS_DESCRIPTIONS
)

app = FastAPI(
    title="OCULIS - Diabetic Retinopathy Screening API",
    description="End-to-end clinical AI screening engine with Image Quality Assessment, CLAHE Enhancement, EfficientNet-B0 Inference, and Grad-CAM Explainability.",
    version="1.0.0"
)

# Enable CORS for frontend development (React, Next.js, Vite, Vue, Angular, etc.)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize the model runner
runner = ScreeningModelRunner()


@app.get("/")
def root():
    return {
        "status": "online",
        "service": "OCULIS DR Screening Pipeline API",
        "version": "1.0.0",
        "model_loaded": runner.is_loaded,
        "model_device": runner.device,
        "endpoints": {
            "screen_image": "POST /api/screen",
            "mock_data": "GET /api/mock",
            "docs": "/docs"
        }
    }


@app.get("/api/mock")
def get_mock_screening_response():
    """
    Returns a pre-configured mock screening response.
    The frontend developer can use this endpoint immediately to build UI components
    without uploading an image or waiting for backend processing.
    """
    mock_file_path = os.path.join(os.path.dirname(__file__), "mock_response.json")
    if os.path.exists(mock_file_path):
        import json
        with open(mock_file_path, "r") as f:
            return json.load(f)

    # Fallback minimal mock
    return {
        "status": "success",
        "patient_id": "PT-MOCK-001",
        "processing_time_ms": 142.5,
        "quality": {
            "status": "Pass",
            "overall_score": 0.892,
            "metrics": {
                "sharpness": 0.880,
                "brightness": 0.910,
                "contrast": 0.885,
                "fov_valid": True
            },
            "rejection_reasons": [],
            "is_acceptable": True
        },
        "prediction": {
            "stage": 2,
            "label": "Moderate NPDR",
            "description": CLASS_DESCRIPTIONS[2],
            "confidence": 0.742,
            "probabilities": {
                "No DR": 0.031,
                "Mild NPDR": 0.082,
                "Moderate NPDR": 0.742,
                "Severe NPDR": 0.115,
                "Proliferative DR": 0.030
            }
        },
        "triage": {
            "is_referable": True,
            "referral_category": "Referable Diabetic Retinopathy",
            "urgency": "Routine Ophthalmology",
            "timeframe": "Schedule consultation within 4 to 6 weeks",
            "recommendation": "Moderate non-proliferative retinopathy identified (Referable DR). Refer to ophthalmologist for comprehensive dilated retinal evaluation.",
            "confidence_score": 0.742
        },
        "enhancement": {
            "applied": True,
            "method": "Selective CLAHE (L-channel equalization)"
        },
        "visuals": {
            "original_image": None,
            "enhanced_image": None,
            "gradcam_overlay": None
        }
    }


@app.post("/api/screen")
async def screen_fundus_image(
    image: UploadFile = File(..., description="Fundus photograph (JPG or PNG)"),
    patient_id: Optional[str] = Form(None, description="Optional Patient or Record ID")
):
    """
    Main screening pipeline endpoint:
    1. Ingestion & Format Validation
    2. Image Quality Assessment (IQA: Sharpness, Brightness, Contrast, FOV)
    3. Selective CLAHE Enhancement
    4. Forward Inference (5-class DR Stage)
    5. Grad-CAM Activation Heatmap Generation
    6. Clinical Triage & Referable DR Decision
    7. Base64 encoding of visual overlays
    """
    start_time = time.time()

    # 1. Validate file format
    if not image.content_type or not (image.content_type.startswith("image/") or image.filename.lower().endswith((".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff"))):
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type '{image.content_type}'. Please upload a standard JPG or PNG fundus image."
        )

    try:
        contents = await image.read()
        pil_img = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Failed to decode image: {str(e)}"
        )

    pid = patient_id if patient_id and patient_id.strip() else f"PT-{int(time.time() * 1000) % 1000000:06d}"

    # 2. Phase 2: Quality Assessment
    quality_result = assess_image_quality(pil_img)

    # 3. Phase 3: Selective CLAHE Enhancement
    enhanced_pil, enhancement_applied = enhance_fundus_image(pil_img, quality_result["status"])

    # 4. Phase 6 & 7: Inference + Grad-CAM Explainability
    pred_stage, probs, gradcam_overlay_pil = runner.predict_and_explain(enhanced_pil)

    # 5. Phase 8: Clinical Triage Logic
    triage_result = make_clinical_triage(pred_stage, probs)

    # 6. Encode Visuals to Base64 for zero-setup frontend rendering
    original_b64 = pil_to_base64(pil_img)
    enhanced_b64 = pil_to_base64(enhanced_pil) if enhancement_applied else original_b64
    gradcam_b64 = pil_to_base64(gradcam_overlay_pil)

    elapsed_ms = round((time.time() - start_time) * 1000.0, 1)

    prob_dict = {CLASS_NAMES[i]: probs[i] for i in range(len(probs))}

    response_payload = {
        "status": "success",
        "patient_id": pid,
        "processing_time_ms": elapsed_ms,
        "quality": quality_result,
        "prediction": {
            "stage": pred_stage,
            "label": CLASS_NAMES[pred_stage],
            "description": CLASS_DESCRIPTIONS[pred_stage],
            "confidence": probs[pred_stage],
            "probabilities": prob_dict
        },
        "triage": triage_result,
        "enhancement": {
            "applied": enhancement_applied,
            "method": "Selective CLAHE (L-channel adaptive equalization)" if enhancement_applied else "None (Optimal baseline exposure)"
        },
        "visuals": {
            "original_image": original_b64,
            "enhanced_image": enhanced_b64,
            "gradcam_overlay": gradcam_b64
        }
    }

    return JSONResponse(content=response_payload)


if __name__ == "__main__":
    import uvicorn
    print("[API Server] Launching OCULIS DR Screening API on http://localhost:8000 ...")
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
