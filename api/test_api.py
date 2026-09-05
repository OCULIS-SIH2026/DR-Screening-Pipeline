"""
Automated Test Suite for DR Screening API
=========================================
Tests health endpoints, mock response schema, and image screening pipeline.
"""

import io
import pytest
from PIL import Image
from fastapi.testclient import TestClient
from app import app

client = TestClient(app)


def test_health_endpoint():
    """Verify API root status and model runner readiness."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "online"
    assert "endpoints" in data
    assert data["endpoints"]["screen_image"] == "POST /api/screen"


def test_mock_endpoint():
    """Verify mock endpoint returns complete contracted schema for frontend."""
    response = client.get("/api/mock")
    assert response.status_code == 200
    data = response.json()

    # Verify top-level contract
    assert data["status"] == "success"
    assert "patient_id" in data
    assert "quality" in data
    assert "prediction" in data
    assert "triage" in data
    assert "visuals" in data

    # Verify prediction structure
    pred = data["prediction"]
    assert "stage" in pred
    assert pred["stage"] in [0, 1, 2, 3, 4]
    assert "label" in pred
    assert "confidence" in pred
    assert "probabilities" in pred
    assert len(pred["probabilities"]) == 5

    # Verify clinical triage
    triage = data["triage"]
    assert "is_referable" in triage
    assert isinstance(triage["is_referable"], bool)
    assert "urgency" in triage
    assert "recommendation" in triage


def test_screen_valid_fundus_image():
    """Verify POST /api/screen with a generated test fundus photograph."""
    # Create synthetic test fundus image
    test_img = Image.new("RGB", (256, 256), color=(140, 50, 25))
    buf = io.BytesIO()
    test_img.save(buf, format="JPEG")
    buf.seek(0)

    response = client.post(
        "/api/screen",
        files={"image": ("sample_fundus.jpg", buf, "image/jpeg")},
        data={"patient_id": "TEST-CI-PATIENT"}
    )

    assert response.status_code == 200
    data = response.json()

    assert data["status"] == "success"
    assert data["patient_id"] == "TEST-CI-PATIENT"

    # Quality check
    assert data["quality"]["status"] in ["Pass", "Borderline", "Reject"]
    assert 0.0 <= data["quality"]["overall_score"] <= 1.0

    # Prediction
    assert data["prediction"]["stage"] in [0, 1, 2, 3, 4]
    assert 0.0 <= data["prediction"]["confidence"] <= 1.0

    # Clinical triage
    assert isinstance(data["triage"]["is_referable"], bool)
    assert data["triage"]["urgency"] != ""

    # Visuals: original, enhanced, and gradcam base64 strings
    visuals = data["visuals"]
    assert visuals["original_image"].startswith("data:image/")
    assert visuals["enhanced_image"].startswith("data:image/")
    assert visuals["gradcam_overlay"].startswith("data:image/")


def test_screen_invalid_file_rejection():
    """Verify that non-image file uploads are gracefully rejected with HTTP 400."""
    text_buf = io.BytesIO(b"This is not a fundus photograph.")
    response = client.post(
        "/api/screen",
        files={"image": ("notes.txt", text_buf, "text/plain")}
    )
    assert response.status_code == 400
    assert "Unsupported file type" in response.json()["detail"]
