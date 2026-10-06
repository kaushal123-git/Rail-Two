from sqlalchemy import Column, String, Boolean, Text
from app.models.base import BaseModel


class FraudModelVersion(BaseModel):
    """
    Registry of trained LOCO ML fraud detection model versions.
    Every prediction is auditable back to the specific version and training dataset.
    """
    __tablename__ = "fraud_model_versions"

    model_name = Column(String(100), nullable=False)
    version = Column(String(50), unique=True, index=True, nullable=False)
    algorithm = Column(String(100), nullable=False)
    training_dataset_version = Column(String(50), nullable=False)
    feature_schema_version = Column(String(50), nullable=False)
    metrics_json = Column(Text, nullable=True)
    thresholds_json = Column(Text, nullable=True)
    artifact_location = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=False, nullable=False)
