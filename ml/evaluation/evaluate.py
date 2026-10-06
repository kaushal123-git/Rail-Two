"""
LOCO Machine Learning Fraud Detection - Model Evaluation & Regression Testing
Version: LOCO-FRAUD-EVAL-v1.0

Loads the production model artifact and runs evaluation or regression testing
against validation or held-out test datasets.
"""

import sys
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

import json
import joblib
import pandas as pd
import numpy as np
from sklearn.metrics import (
    roc_auc_score,
    average_precision_score,
    precision_score,
    recall_score,
    f1_score,
    confusion_matrix,
    classification_report,
)
from ml.features.schema import FEATURE_NAMES


def run_evaluation(
    model_path: str = None,
    preprocessor_path: str = None,
    dataset_path: str = None,
) -> dict:
    ml_root = os.path.join(PROJECT_ROOT, "ml")
    if not model_path:
        model_path = os.path.join(ml_root, "models", "loco_fraud_v1.0.joblib")
    if not preprocessor_path:
        preprocessor_path = os.path.join(ml_root, "models", "preprocessor_v1.0.joblib")
    if not dataset_path:
        dataset_path = os.path.join(ml_root, "datasets", "processed", "test.csv")

    print(f"[Evaluate] Loading model: {model_path}")
    print(f"[Evaluate] Loading preprocessor: {preprocessor_path}")
    print(f"[Evaluate] Loading dataset: {dataset_path}")

    model = joblib.load(model_path)
    preprocessor = joblib.load(preprocessor_path)
    df = pd.read_csv(dataset_path)

    X = preprocessor.transform(df[FEATURE_NAMES])
    y = df["is_fraud"].values.astype(int)

    probs = model.predict_proba(X)[:, 1]
    preds = (probs >= 0.5).astype(int)

    roc_auc = float(roc_auc_score(y, probs))
    pr_auc = float(average_precision_score(y, probs))
    prec = float(precision_score(y, preds, zero_division=0))
    rec = float(recall_score(y, preds, zero_division=0))
    f1 = float(f1_score(y, preds, zero_division=0))
    cm = confusion_matrix(y, preds).tolist()

    report = classification_report(
        y, preds, target_names=["Legitimate", "Fraudulent"], output_dict=True
    )

    results = {
        "sample_count": len(y),
        "fraud_count": int(y.sum()),
        "roc_auc": round(roc_auc, 4),
        "pr_auc": round(pr_auc, 4),
        "precision": round(prec, 4),
        "recall": round(rec, 4),
        "f1_score": round(f1, 4),
        "confusion_matrix": cm,
        "classification_report": report,
    }

    print("\n--- Model Evaluation Summary ---")
    print(f"Samples: {len(y)} | Fraud Count: {int(y.sum())}")
    print(f"ROC-AUC: {roc_auc:.4f} | PR-AUC: {pr_auc:.4f} | F1: {f1:.4f}")
    print(f"Precision: {prec:.4f} | Recall: {rec:.4f}")
    print(f"Confusion Matrix: {cm}")

    return results


if __name__ == "__main__":
    run_evaluation()
