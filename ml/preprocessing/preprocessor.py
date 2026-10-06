"""
LOCO Machine Learning Fraud Detection - Feature Preprocessor
Version: LOCO-FRAUD-PREPROCESSOR-v1.0

Applies deterministic missing value imputation, domain-safe value clipping,
and robust scaling across the 52 LOCO fraud features.
Maintains identical transformation logic for training and production inference.
"""

from typing import Dict, Any, List, Union
import numpy as np
import pandas as pd
from sklearn.base import BaseEstimator, TransformerMixin
from sklearn.preprocessing import RobustScaler
from ml.features.schema import FEATURE_NAMES, FraudFeatureVector


# Domain-valid clipping limits to prevent numerical explosion or adversarial outliers
FEATURE_CLIPPING_BOUNDS: Dict[str, tuple] = {
    "gps_accuracy": (0.0, 1000.0),
    "distance_from_expected_station": (0.0, 100000.0),
    "distance_from_route": (0.0, 50000.0),
    "speed_kmh": (0.0, 500.0),
    "acceleration": (0.0, 25.0),
    "bearing_change": (0.0, 180.0),
    "location_jump_distance": (0.0, 500000.0),
    "location_jump_time": (0.01, 86400.0),
    "location_update_frequency": (0.0, 120.0),
    "location_confidence": (0.0, 1.0),
    "mock_location_signal": (0.0, 1.0),
    "location_replay_signal": (0.0, 1.0),
    "journey_duration": (0.0, 86400.0),
    "expected_journey_duration": (60.0, 86400.0),
    "journey_progress": (0.0, 1.0),
    "route_deviation_distance": (0.0, 50000.0),
    "boarding_station_match": (0.0, 1.0),
    "destination_match": (0.0, 1.0),
    "station_transition_time": (0.0, 7200.0),
    "number_of_route_deviations": (0.0, 50.0),
    "tickets_created_24h": (0.0, 100.0),
    "tickets_created_7d": (0.0, 300.0),
    "active_ticket_count": (0.0, 20.0),
    "ticket_reuse_count": (0.0, 50.0),
    "ticket_age": (0.0, 604800.0),
    "ticket_validity_remaining": (-86400.0, 604800.0),
    "ticket_location_mismatch": (0.0, 1.0),
    "ticket_state_consistency": (0.0, 1.0),
    "payment_attempts_24h": (0.0, 100.0),
    "payment_failures_24h": (0.0, 100.0),
    "payment_success_rate": (0.0, 1.0),
    "payment_amount": (0.0, 5000.0),
    "payment_retry_count": (0.0, 20.0),
    "payment_ticket_consistency": (0.0, 1.0),
    "account_age_days": (0.0, 3650.0),
    "login_count_24h": (0.0, 100.0),
    "otp_requests_24h": (0.0, 50.0),
    "otp_failures_24h": (0.0, 50.0),
    "device_change_count": (0.0, 20.0),
    "session_count_24h": (0.0, 50.0),
    "device_age_days": (0.0, 3650.0),
    "device_integrity_status": (0.0, 1.0),
    "root_detected": (0.0, 1.0),
    "jailbreak_detected": (0.0, 1.0),
    "emulator_detected": (0.0, 1.0),
    "app_integrity_status": (0.0, 1.0),
    "play_integrity_status": (0.0, 1.0),
    "app_attest_status": (0.0, 1.0),
    "network_change_frequency": (0.0, 60.0),
    "suspicious_network_signal": (0.0, 1.0),
    "vpn_signal": (0.0, 1.0),
    "proxy_signal": (0.0, 1.0),
}


class FraudPreprocessor(BaseEstimator, TransformerMixin):
    """
    Scikit-learn compatible preprocessor for LOCO fraud detection.
    Guarantees consistent feature ordering, null imputation, domain clipping,
    and robust outlier-resistant scaling.
    """

    def __init__(self, use_scaler: bool = True):
        self.use_scaler = use_scaler
        self.feature_names: List[str] = list(FEATURE_NAMES)
        self.default_vector = FraudFeatureVector()
        self.impute_values: Dict[str, float] = {}
        self.scaler: RobustScaler = RobustScaler()
        self.is_fitted: bool = False

    def fit(self, X: Union[pd.DataFrame, np.ndarray, List[Dict[str, Any]]], y=None):
        """Fit imputation medians and scaler parameters on training data."""
        df = self._to_dataframe(X)

        # 1. Compute robust imputation values (median per column)
        for col in self.feature_names:
            if col in df.columns:
                med = df[col].median()
                self.impute_values[col] = float(med) if pd.notna(med) else float(getattr(self.default_vector, col))
            else:
                self.impute_values[col] = float(getattr(self.default_vector, col))

        # 2. Impute and clip
        imputed_clipped = self._impute_and_clip(df)

        # 3. Fit scaler
        if self.use_scaler:
            self.scaler.fit(imputed_clipped.values)

        self.is_fitted = True
        return self

    def transform(self, X: Union[pd.DataFrame, np.ndarray, List[Dict[str, Any]], Dict[str, Any], FraudFeatureVector]) -> np.ndarray:
        """Transform features into normalized numerical matrix for model inference."""
        if not self.is_fitted:
            # Fall back to default feature vector statistics if not yet explicitly fitted
            for col in self.feature_names:
                self.impute_values[col] = float(getattr(self.default_vector, col))
            self.is_fitted = True

        # High-performance fast-path for single sample inference (avoids pandas overhead in real-time scoring)
        if isinstance(X, (FraudFeatureVector, dict)):
            d = X.to_dict() if isinstance(X, FraudFeatureVector) else X
            vals = []
            for col in self.feature_names:
                raw_val = d.get(col)
                if raw_val is None or (isinstance(raw_val, float) and np.isnan(raw_val)):
                    val = self.impute_values.get(col, float(getattr(self.default_vector, col)))
                else:
                    val = float(raw_val)
                bounds = FEATURE_CLIPPING_BOUNDS.get(col)
                if bounds:
                    val = max(bounds[0], min(bounds[1], val))
                vals.append(val)
            arr = np.array([vals], dtype=np.float64)
            if self.use_scaler and hasattr(self.scaler, "center_") and self.scaler.center_ is not None:
                return self.scaler.transform(arr)
            return arr

        df = self._to_dataframe(X)
        imputed_clipped = self._impute_and_clip(df)

        if self.use_scaler and hasattr(self.scaler, "center_") and self.scaler.center_ is not None:
            return self.scaler.transform(imputed_clipped.values)
        return imputed_clipped.values


    def _to_dataframe(self, X: Any) -> pd.DataFrame:
        """Normalize varied input formats into aligned DataFrame with FEATURE_NAMES columns."""
        if isinstance(X, FraudFeatureVector):
            return pd.DataFrame([X.to_dict()])
        elif isinstance(X, dict):
            return pd.DataFrame([X])
        elif isinstance(X, list):
            if len(X) == 0:
                return pd.DataFrame(columns=self.feature_names)
            if isinstance(X[0], dict):
                return pd.DataFrame(X)
            elif isinstance(X[0], FraudFeatureVector):
                return pd.DataFrame([x.to_dict() for x in X])
            elif isinstance(X[0], (list, tuple)):
                return pd.DataFrame(X, columns=self.feature_names[:len(X[0])])
        elif isinstance(X, np.ndarray):
            if X.ndim == 1:
                return pd.DataFrame([X], columns=self.feature_names[:len(X)])
            return pd.DataFrame(X, columns=self.feature_names[:X.shape[1]])
        elif isinstance(X, pd.DataFrame):
            return X.copy()
        raise ValueError(f"Unsupported feature input type: {type(X)}")

    def _impute_and_clip(self, df: pd.DataFrame) -> pd.DataFrame:
        """Apply missing value imputation, order enforcement, and bounds clipping."""
        result = pd.DataFrame(index=df.index)
        for col in self.feature_names:
            if col in df.columns:
                series = df[col].copy()
                fallback = self.impute_values.get(col, float(getattr(self.default_vector, col)))
                series = series.fillna(fallback)
            else:
                fallback = self.impute_values.get(col, float(getattr(self.default_vector, col)))
                series = pd.Series(fallback, index=df.index)

            # Apply domain clipping
            if col in FEATURE_CLIPPING_BOUNDS:
                lower, upper = FEATURE_CLIPPING_BOUNDS[col]
                series = series.clip(lower=lower, upper=upper)

            result[col] = series.astype(float)
        return result
