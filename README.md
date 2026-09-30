# Pir — Digital Rights Intelligence Platform

A Supabase-first, modular foundation for an authorized digital copyright monitoring and enforcement platform.

## Architecture
- TanStack Start / React frontend
- Supabase Auth + Postgres + Storage + Realtime
- pgvector for similarity search
- FastAPI workers for CPU/ML-heavy processing
- Redis/Celery for asynchronous jobs where required
- GitHub Actions for CI

## Enforcement principle
The platform detects and organizes suspected infringement and prepares authorized enforcement cases. It must not fabricate ownership/evidence, bypass access controls, or submit unsupported complaints. Platform-specific enforcement adapters use official/current reporting mechanisms and legal review where required.

## First milestone
Rights-holder → asset → detection → evidence → case → authorized enforcement action → removal verification → reappearance.
