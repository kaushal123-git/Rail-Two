"""0005_phase5_custom_ml_fraud_engine

Revision ID: 0005_phase5_custom_ml_fraud_engine
Revises: 0004_phase4_geofencing_journeys_location_integrity
Create Date: 2026-10-06 18:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '0005_phase5_custom_ml_fraud_engine'
down_revision: Union[str, None] = '0004_phase4_geofencing_journeys_location_integrity'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. fraud_model_versions table
    op.create_table(
        'fraud_model_versions',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('model_name', sa.String(length=100), nullable=False),
        sa.Column('version', sa.String(length=50), nullable=False, unique=True),
        sa.Column('algorithm', sa.String(length=100), nullable=False),
        sa.Column('training_dataset_version', sa.String(length=50), nullable=False),
        sa.Column('feature_schema_version', sa.String(length=50), nullable=False),
        sa.Column('metrics_json', sa.Text(), nullable=True),
        sa.Column('thresholds_json', sa.Text(), nullable=True),
        sa.Column('artifact_location', sa.String(length=255), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f('ix_fraud_model_versions_id'), 'fraud_model_versions', ['id'], unique=False)
    op.create_index(op.f('ix_fraud_model_versions_version'), 'fraud_model_versions', ['version'], unique=True)

    # 2. fraud_feature_snapshots table
    op.create_table(
        'fraud_feature_snapshots',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('user_id', sa.String(length=36), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('ticket_id', sa.String(length=36), sa.ForeignKey('tickets.id', ondelete='SET NULL'), nullable=True),
        sa.Column('journey_id', sa.String(length=36), sa.ForeignKey('journeys.id', ondelete='SET NULL'), nullable=True),
        sa.Column('feature_schema_version', sa.String(length=50), nullable=False, server_default='LOCO-FRAUD-FEATURE-v1.0'),
        sa.Column('features_json', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f('ix_fraud_feature_snapshots_id'), 'fraud_feature_snapshots', ['id'], unique=False)
    op.create_index(op.f('ix_fraud_feature_snapshots_user_id'), 'fraud_feature_snapshots', ['user_id'], unique=False)
    op.create_index(op.f('ix_fraud_feature_snapshots_ticket_id'), 'fraud_feature_snapshots', ['ticket_id'], unique=False)
    op.create_index(op.f('ix_fraud_feature_snapshots_journey_id'), 'fraud_feature_snapshots', ['journey_id'], unique=False)

    # 3. fraud_predictions table
    op.create_table(
        'fraud_predictions',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('user_id', sa.String(length=36), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('ticket_id', sa.String(length=36), sa.ForeignKey('tickets.id', ondelete='SET NULL'), nullable=True),
        sa.Column('journey_id', sa.String(length=36), sa.ForeignKey('journeys.id', ondelete='SET NULL'), nullable=True),
        sa.Column('feature_snapshot_id', sa.String(length=36), sa.ForeignKey('fraud_feature_snapshots.id', ondelete='SET NULL'), nullable=True),
        sa.Column('model_version', sa.String(length=50), nullable=False),
        sa.Column('risk_score', sa.Float(), nullable=False),
        sa.Column('probability', sa.Float(), nullable=False),
        sa.Column('risk_level', sa.String(length=20), nullable=False),
        sa.Column('top_features_json', sa.Text(), nullable=True),
        sa.Column('inference_latency_ms', sa.Float(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f('ix_fraud_predictions_id'), 'fraud_predictions', ['id'], unique=False)
    op.create_index(op.f('ix_fraud_predictions_user_id'), 'fraud_predictions', ['user_id'], unique=False)
    op.create_index(op.f('ix_fraud_predictions_ticket_id'), 'fraud_predictions', ['ticket_id'], unique=False)
    op.create_index(op.f('ix_fraud_predictions_journey_id'), 'fraud_predictions', ['journey_id'], unique=False)
    op.create_index(op.f('ix_fraud_predictions_model_version'), 'fraud_predictions', ['model_version'], unique=False)

    # 4. fraud_decisions table
    op.create_table(
        'fraud_decisions',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('prediction_id', sa.String(length=36), sa.ForeignKey('fraud_predictions.id', ondelete='SET NULL'), nullable=True),
        sa.Column('user_id', sa.String(length=36), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('ticket_id', sa.String(length=36), sa.ForeignKey('tickets.id', ondelete='SET NULL'), nullable=True),
        sa.Column('journey_id', sa.String(length=36), sa.ForeignKey('journeys.id', ondelete='SET NULL'), nullable=True),
        sa.Column('decision', sa.String(length=30), nullable=False),
        sa.Column('risk_state', sa.String(length=30), nullable=False),
        sa.Column('reason', sa.Text(), nullable=False),
        sa.Column('triggered_rules_json', sa.Text(), nullable=True),
        sa.Column('rule_version', sa.String(length=50), nullable=False, server_default='LOCO-RULES-v1.0'),
        sa.Column('review_status', sa.String(length=30), nullable=False, server_default='AUTOMATED'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f('ix_fraud_decisions_id'), 'fraud_decisions', ['id'], unique=False)
    op.create_index(op.f('ix_fraud_decisions_user_id'), 'fraud_decisions', ['user_id'], unique=False)
    op.create_index(op.f('ix_fraud_decisions_ticket_id'), 'fraud_decisions', ['ticket_id'], unique=False)
    op.create_index(op.f('ix_fraud_decisions_journey_id'), 'fraud_decisions', ['journey_id'], unique=False)
    op.create_index(op.f('ix_fraud_decisions_decision'), 'fraud_decisions', ['decision'], unique=False)

    # 5. fraud_rule_events table
    op.create_table(
        'fraud_rule_events',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('decision_id', sa.String(length=36), sa.ForeignKey('fraud_decisions.id', ondelete='CASCADE'), nullable=False),
        sa.Column('rule_code', sa.String(length=50), nullable=False),
        sa.Column('rule_severity', sa.String(length=20), nullable=False),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('metadata_json', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f('ix_fraud_rule_events_id'), 'fraud_rule_events', ['id'], unique=False)
    op.create_index(op.f('ix_fraud_rule_events_decision_id'), 'fraud_rule_events', ['decision_id'], unique=False)
    op.create_index(op.f('ix_fraud_rule_events_rule_code'), 'fraud_rule_events', ['rule_code'], unique=False)


def downgrade() -> None:
    op.drop_table('fraud_rule_events')
    op.drop_table('fraud_decisions')
    op.drop_table('fraud_predictions')
    op.drop_table('fraud_feature_snapshots')
    op.drop_table('fraud_model_versions')
