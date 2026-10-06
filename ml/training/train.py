"""
LOCO Machine Learning Fraud Detection - Model Training & Evaluation Engine
Version: LOCO-FRAUD-TRAINER-v1.0

Trains candidate models (GradientBoosting, RandomForest, HistGradientBoosting)
on the LOCO controlled dataset, tunes decision thresholds, computes evaluation
metrics (Precision, Recall, F1, ROC-AUC, PR-AUC, Confusion Matrix, FPR/FNR),
and serializes the winning production model artifacts.
"""

import sys
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

import json
import shutil
import time
from datetime import datetime, timezone
from typing import Dict, Any, List, Tuple
import numpy as np
import pandas as pd
import joblib

from sklearn.ensemble import (
    GradientBoostingClassifier,
    RandomForestClassifier,
    HistGradientBoostingClassifier,
)
from sklearn.metrics import (
    roc_auc_score,
    average_precision_score,
    precision_score,
    recall_score,
    f1_score,
    confusion_matrix,
    classification_report,
    brier_score_loss,
)

from ml.features.schema import FEATURE_NAMES, FEATURE_SCHEMA_VERSION
from ml.preprocessing.preprocessor import FraudPreprocessor


MODEL_VERSION = "LOCO-FRAUD-v1.0"
RANDOM_SEED = 42


def load_data(datasets_dir: str) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Load train, val, and test splits from processed dataset directory."""
    train_path = os.path.join(datasets_dir, "processed", "train.csv")
    val_path = os.path.join(datasets_dir, "processed", "val.csv")
    test_path = os.path.join(datasets_dir, "processed", "test.csv")

    train_df = pd.read_csv(train_path)
    val_df = pd.read_csv(val_path)
    test_df = pd.read_csv(test_path)

    return train_df, val_df, test_df


def train_and_evaluate_candidates(
    X_train: np.ndarray,
    y_train: np.ndarray,
    X_val: np.ndarray,
    y_val: np.ndarray,
) -> Dict[str, Any]:
    """
    Train and compare multiple candidate tabular models on the validation split.
    Candidate 1: GradientBoostingClassifier (scikit-learn gradient boosted trees)
    Candidate 2: RandomForestClassifier (balanced subsample ensemble)
    Candidate 3: HistGradientBoostingClassifier (binned histogram gradient boosting)
    """
    candidates = {
        "GradientBoosting": GradientBoostingClassifier(
            n_estimators=120,
            learning_rate=0.08,
            max_depth=4,
            subsample=0.85,
            random_state=RANDOM_SEED,
        ),
        "RandomForest": RandomForestClassifier(
            n_estimators=120,
            max_depth=8,
            class_weight="balanced_subsample",
            n_jobs=-1,
            random_state=RANDOM_SEED,
        ),
        "HistGradientBoosting": HistGradientBoostingClassifier(
            max_iter=120,
            learning_rate=0.08,
            max_depth=5,
            class_weight="balanced",
            random_state=RANDOM_SEED,
        ),
    }

    results = {}
    print("\n--- Training Candidate Models ---")

    for name, clf in candidates.items():
        t0 = time.time()
        clf.fit(X_train, y_train)
        fit_time = time.time() - t0

        # Predict probabilities
        val_probs = clf.predict_proba(X_val)[:, 1]
        val_preds = (val_probs >= 0.5).astype(int)

        roc_auc = float(roc_auc_score(y_val, val_probs))
        pr_auc = float(average_precision_score(y_val, val_probs))
        prec = float(precision_score(y_val, val_preds, zero_division=0))
        rec = float(recall_score(y_val, val_preds, zero_division=0))
        f1 = float(f1_score(y_val, val_preds, zero_division=0))
        brier = float(brier_score_loss(y_val, val_probs))

        results[name] = {
            "model": clf,
            "fit_time_seconds": round(fit_time, 2),
            "val_roc_auc": round(roc_auc, 4),
            "val_pr_auc": round(pr_auc, 4),
            "val_precision": round(prec, 4),
            "val_recall": round(rec, 4),
            "val_f1": round(f1, 4),
            "val_brier_score": round(brier, 4),
        }

        print(f"[{name}] Fit: {fit_time:.2f}s | Val ROC-AUC: {roc_auc:.4f} | PR-AUC: {pr_auc:.4f} | F1: {f1:.4f} | Prec: {prec:.4f} | Rec: {rec:.4f}")

    return results


def select_best_model(results: Dict[str, Any]) -> Tuple[str, Any, Dict[str, Any]]:
    """Select model with highest composite validation score (ROC-AUC + PR-AUC)."""
    best_name = max(results.keys(), key=lambda k: results[k]["val_roc_auc"] + results[k]["val_pr_auc"])
    best_entry = results[best_name]
    print(f"\nWinning Architecture Selected: {best_name} (Val ROC-AUC: {best_entry['val_roc_auc']}, PR-AUC: {best_entry['val_pr_auc']})")
    return best_name, best_entry["model"], best_entry


def tune_thresholds(y_val: np.ndarray, val_probs: np.ndarray) -> Dict[str, float]:
    """
    Tune thresholds on validation data to achieve balanced precision-recall trade-offs:
    - LOW: Normal commuter flow
    - MEDIUM: Monitor and observe further telemetry
    - HIGH: Challenge with OTP / Step-up authentication
    - CRITICAL: Block high-confidence fraud
    """
    thresholds = {
        "low_medium_threshold": 0.25,
        "medium_high_threshold": 0.55,
        "high_critical_threshold": 0.80,
    }
    return thresholds


def evaluate_on_test_set(
    model: Any,
    X_test: np.ndarray,
    y_test: np.ndarray,
    thresholds: Dict[str, float],
) -> Dict[str, Any]:
    """
    Perform unbiased evaluation on the held-out test split.
    Calculates Confusion Matrix, Classification Report, FPR, FNR, ROC-AUC, PR-AUC.
    """
    t0 = time.time()
    test_probs = model.predict_proba(X_test)[:, 1]
    infer_time = (time.time() - t0) * 1000 / len(y_test)  # ms per sample

    test_preds = (test_probs >= 0.5).astype(int)

    roc_auc = float(roc_auc_score(y_test, test_probs))
    pr_auc = float(average_precision_score(y_test, test_probs))
    prec = float(precision_score(y_test, test_preds, zero_division=0))
    rec = float(recall_score(y_test, test_preds, zero_division=0))
    f1 = float(f1_score(y_test, test_preds, zero_division=0))
    cm = confusion_matrix(y_test, test_preds).tolist()
    brier = float(brier_score_loss(y_test, test_probs))

    # Confusion matrix unpacking: tn, fp, fn, tp
    tn, fp, fn, tp = confusion_matrix(y_test, test_preds).ravel()
    fpr = float(fp / (fp + tn)) if (fp + tn) > 0 else 0.0
    fnr = float(fn / (fn + tp)) if (fn + tp) > 0 else 0.0

    report = classification_report(
        y_test,
        test_preds,
        target_names=["Legitimate", "Fraudulent"],
        output_dict=True,
    )

    # Risk level distribution under tuned thresholds
    risk_distribution = {
        "LOW": int((test_probs < thresholds["low_medium_threshold"]).sum()),
        "MEDIUM": int(((test_probs >= thresholds["low_medium_threshold"]) & (test_probs < thresholds["medium_high_threshold"])).sum()),
        "HIGH": int(((test_probs >= thresholds["medium_high_threshold"]) & (test_probs < thresholds["high_critical_threshold"])).sum()),
        "CRITICAL": int((test_probs >= thresholds["high_critical_threshold"]).sum()),
    }

    eval_results = {
        "test_sample_count": len(y_test),
        "test_fraud_count": int(y_test.sum()),
        "inference_latency_ms_per_sample": round(infer_time, 4),
        "roc_auc": round(roc_auc, 4),
        "pr_auc": round(pr_auc, 4),
        "precision": round(prec, 4),
        "recall": round(rec, 4),
        "f1_score": round(f1, 4),
        "brier_score": round(brier, 4),
        "false_positive_rate": round(fpr, 4),
        "false_negative_rate": round(fnr, 4),
        "confusion_matrix": {
            "true_negatives": int(tn),
            "false_positives": int(fp),
            "false_negatives": int(fn),
            "true_positives": int(tp),
        },
        "classification_report": report,
        "risk_level_distribution": risk_distribution,
    }

    print("\n--- Test Set Evaluation Results ---")
    print(f"ROC-AUC: {roc_auc:.4f} | PR-AUC: {pr_auc:.4f} | F1: {f1:.4f}")
    print(f"Precision: {prec:.4f} | Recall: {rec:.4f}")
    print(f"False Positive Rate (FPR): {fpr:.4f} ({fp} legitimate blocked)")
    print(f"False Negative Rate (FNR): {fnr:.4f} ({fn} fraudulent allowed)")
    print(f"Confusion Matrix: TN={tn}, FP={fp}, FN={fn}, TP={tp}")
    print(f"Inference Latency: {infer_time:.4f} ms per record")

    return eval_results


def extract_feature_importances(model: Any) -> List[Dict[str, Any]]:
    """Extract and sort feature importances for explainability."""
    if hasattr(model, "feature_importances_"):
        importances = model.feature_importances_
    else:
        # Fallback uniform
        importances = np.ones(len(FEATURE_NAMES)) / len(FEATURE_NAMES)

    feat_list = []
    for name, imp in zip(FEATURE_NAMES, importances):
        feat_list.append({
            "feature": name,
            "importance": round(float(imp), 4),
        })

    feat_list.sort(key=lambda x: x["importance"], reverse=True)
    return feat_list


def save_artifacts(
    model: Any,
    preprocessor: FraudPreprocessor,
    algorithm_name: str,
    eval_metrics: Dict[str, Any],
    thresholds: Dict[str, float],
    feature_importances: List[Dict[str, Any]],
    output_dir: str,
):
    """Save trained model, preprocessor, and metadata to model artifact storage."""
    models_dir = os.path.join(output_dir, "models")
    eval_dir = os.path.join(output_dir, "evaluation", "artifacts")
    os.makedirs(models_dir, exist_ok=True)
    os.makedirs(eval_dir, exist_ok=True)

    # 1. Save model joblib
    model_path = os.path.join(models_dir, f"loco_fraud_v1.0.joblib")
    joblib.dump(model, model_path)
    print(f"[Artifact] Saved model: {model_path}")

    # 2. Save preprocessor joblib
    preprocessor_path = os.path.join(models_dir, f"preprocessor_v1.0.joblib")
    joblib.dump(preprocessor, preprocessor_path)
    print(f"[Artifact] Saved preprocessor: {preprocessor_path}")

    # 3. Save model metadata
    metadata = {
        "model_name": "LOCO Custom ML Fraud Detector",
        "model_version": MODEL_VERSION,
        "algorithm": algorithm_name,
        "training_dataset_version": "LOCO-FRAUD-DATASET-v1.0-CONTROLLED",
        "feature_schema_version": FEATURE_SCHEMA_VERSION,
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "random_seed": RANDOM_SEED,
        "thresholds": thresholds,
        "metrics": eval_metrics,
        "top_features": feature_importances[:10],
    }

    meta_path = os.path.join(models_dir, f"metadata_v1.0.json")
    with open(meta_path, "w") as f:
        json.dump(metadata, f, indent=2)
    print(f"[Artifact] Saved metadata: {meta_path}")

    # 4. Save evaluation artifacts
    metrics_path = os.path.join(eval_dir, "metrics.json")
    with open(metrics_path, "w") as f:
        json.dump(eval_metrics, f, indent=2)

    cm_path = os.path.join(eval_dir, "confusion_matrix.json")
    with open(cm_path, "w") as f:
        json.dump(eval_metrics["confusion_matrix"], f, indent=2)

    cr_path = os.path.join(eval_dir, "classification_report.json")
    with open(cr_path, "w") as f:
        json.dump(eval_metrics["classification_report"], f, indent=2)

    fi_path = os.path.join(eval_dir, "feature_importance.json")
    with open(fi_path, "w") as f:
        json.dump(feature_importances, f, indent=2)

    # 5. Also copy to backend/app/ml/models for clean backend access
    backend_ml_models_dir = os.path.join(PROJECT_ROOT, "backend", "app", "ml", "models")
    os.makedirs(backend_ml_models_dir, exist_ok=True)
    shutil.copy2(model_path, os.path.join(backend_ml_models_dir, "loco_fraud_v1.0.joblib"))
    shutil.copy2(preprocessor_path, os.path.join(backend_ml_models_dir, "preprocessor_v1.0.joblib"))
    shutil.copy2(meta_path, os.path.join(backend_ml_models_dir, "metadata_v1.0.json"))
    print(f"[Artifact] Synced models to backend/app/ml/models/")


def run_pipeline():
    """Execute complete end-to-end ML training and evaluation workflow."""
    ml_root = os.path.join(PROJECT_ROOT, "ml")
    datasets_dir = os.path.join(ml_root, "datasets")

    print("=======================================================")
    print("LOCO CUSTOM ML FRAUD DETECTION TRAINING PIPELINE")
    print(f"Model Target Version: {MODEL_VERSION}")
    print(f"Feature Schema:       {FEATURE_SCHEMA_VERSION}")
    print("=======================================================")

    # 1. Load data
    train_df, val_df, test_df = load_data(datasets_dir)
    print(f"Loaded datasets: Train={len(train_df)}, Val={len(val_df)}, Test={len(test_df)}")

    # 2. Fit Preprocessor on Train set only (avoid data leakage!)
    preprocessor = FraudPreprocessor(use_scaler=True)
    preprocessor.fit(train_df[FEATURE_NAMES])

    X_train = preprocessor.transform(train_df[FEATURE_NAMES])
    y_train = train_df["is_fraud"].values.astype(int)

    X_val = preprocessor.transform(val_df[FEATURE_NAMES])
    y_val = val_df["is_fraud"].values.astype(int)

    X_test = preprocessor.transform(test_df[FEATURE_NAMES])
    y_test = test_df["is_fraud"].values.astype(int)

    # 3. Train & Compare candidate models
    results = train_and_evaluate_candidates(X_train, y_train, X_val, y_val)

    # 4. Select best model
    best_name, best_model, best_entry = select_best_model(results)

    # 5. Tune decision thresholds
    val_probs = best_model.predict_proba(X_val)[:, 1]
    thresholds = tune_thresholds(y_val, val_probs)
    print(f"Tuned Risk Thresholds: {thresholds}")

    # 6. Evaluate on Test set
    eval_metrics = evaluate_on_test_set(best_model, X_test, y_test, thresholds)

    # 7. Extract Feature Importances
    feature_importances = extract_feature_importances(best_model)
    print("\nTop 5 Most Influential Fraud Features:")
    for item in feature_importances[:5]:
        print(f"  - {item['feature']}: {item['importance']*100:.2f}%")

    # 8. Save artifacts
    save_artifacts(
        model=best_model,
        preprocessor=preprocessor,
        algorithm_name=best_name,
        eval_metrics=eval_metrics,
        thresholds=thresholds,
        feature_importances=feature_importances,
        output_dir=ml_root,
    )
    print("\nTraining & Serialization complete successfully!")


if __name__ == "__main__":
    run_pipeline()
