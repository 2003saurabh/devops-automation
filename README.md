# AWS SageMaker Deep Dive — MLA-C01 Study Guide

> **Exam:** AWS Certified Machine Learning Engineer – Associate (MLA-C01)  
> **Format:** 85 questions | 170 minutes | $150 USD  
> **Question Types:** Multiple choice, Multiple select, Ordering, Matching, Case Study

---

## Exam Domains & Weightage

| Domain | Topic | Weight |
|--------|-------|--------|
| 1 | Data Preparation for Machine Learning | ~28% |
| 2 | ML Model Development | ~26% |
| 3 | Deployment and Orchestration of ML Workflows | ~22% |
| 4 | ML Solution Monitoring, Maintenance, and Security | ~24% |

> SageMaker is the **core service** across all 4 domains. Treat this as the "SageMaker certification."

---

## Phase 1 — Foundation (Week 1–2)

### Step 1: Understand the ML Lifecycle

Before touching SageMaker, be solid on these concepts:

- Supervised vs Unsupervised vs Reinforcement Learning
- Regression vs Classification — and their evaluation metrics
  - Regression: RMSE, MAE, R²
  - Classification: Accuracy, Precision, Recall, F1, AUC-ROC
- Overfitting vs Underfitting — regularization (L1/L2), dropout, early stopping
- Train / Validation / Test split strategies
- Feature engineering basics — normalization, encoding, imputation
- Bias-variance tradeoff

### Step 2: AWS Prerequisites

Make sure you're comfortable with:

- **IAM** — roles, policies, trust relationships (SageMaker needs IAM roles for almost everything)
- **S3** — buckets, prefixes, versioning, lifecycle policies (SageMaker stores data/models here)
- **VPC** — subnets, security groups, private endpoints (SageMaker runs inside VPCs)
- **CloudWatch** — logs, metrics, alarms
- **ECR** — container registries (custom training/inference containers)

---

## Phase 2 — SageMaker Core Services (Week 3–5)

Work through these in order. Each builds on the previous.

---

### 2.1 SageMaker Studio & Development Environments

| Tool | What it is | When to use |
|------|-----------|-------------|
| **SageMaker Studio** | Web-based ML IDE — all-in-one | Primary workspace for everything |
| **SageMaker Notebooks** | Managed Jupyter on EC2 | Data exploration, prototyping |
| **SageMaker Canvas** | No-code ML interface | Business users, quick forecasting |
| **SageMaker Domains** | Secure network + user management | Team/org-level setup |

**Key things to know:**
- Studio Domains define the network boundary and user profiles
- Notebooks are billed per instance-hour — stop them when not in use
- Canvas supports fraud detection, forecasting, churn prediction out of the box

---

### 2.2 Data Preparation

#### SageMaker Data Wrangler
- Visual, low-code data prep and feature engineering tool
- Connects to S3, Athena, Redshift, EMR
- Generates transformation code (PySpark / Pandas)
- Exports to Feature Store, Processing Jobs, or Pipelines
- **Exam tip:** Use Data Wrangler for interactive, GUI-based data prep. Use AWS Glue for large-scale ETL pipelines.

#### SageMaker Processing Jobs
- Run data preprocessing, feature engineering, or model evaluation as managed jobs
- Supports custom scripts (Python, Spark)
- Fully managed compute — you define instance type and count

#### SageMaker Feature Store
- Centralized store for ML features
- **Online store** — low-latency, real-time inference lookups
- **Offline store** — S3-backed, for training
- Supports feature reuse across teams and models

**Exam tip:** Know when to use online vs offline store. Online = real-time serving. Offline = batch training.

---

### 2.3 Model Training

#### Training Jobs
- Managed infrastructure for model training
- You provide: algorithm/container, data location (S3), instance type, hyperparameters
- Supports distributed training (data parallelism, model parallelism)
- Output artifacts saved to S3

#### Built-in Algorithms
Know these well — the exam tests when to use each:

| Algorithm | Type | Use Case |
|-----------|------|----------|
| XGBoost | Classification/Regression | Tabular data, most common |
| Linear Learner | Classification/Regression | Fast, interpretable |
| BlazingText | NLP | Text classification, Word2Vec |
| Object Detection | CV | Bounding boxes in images |
| Image Classification | CV | Image labeling |
| Semantic Segmentation | CV | Pixel-level classification |
| K-Means | Clustering | Unsupervised grouping |
| PCA | Dimensionality Reduction | Feature reduction |
| DeepAR | Forecasting | Time series with multiple related series |
| Factorization Machines | Recommendation | Sparse data, click prediction |
| IP Insights | Anomaly Detection | Unusual IP behavior |
| Random Cut Forest (RCF) | Anomaly Detection | Streaming anomaly detection |

#### Hyperparameter Tuning (HPO)
- **Automatic Model Tuning (AMT)** — SageMaker's HPO service
- Strategies: Bayesian (default, most efficient), Random, Grid, Hyperband
- Define objective metric, parameter ranges, max jobs
- **Warm start** — reuse previous tuning job results

#### Distributed Training
- **Data Parallelism** — split data across GPUs/instances, same model copy
- **Model Parallelism** — split model across GPUs (for very large models)
- SageMaker Distributed Training Library supports both

---

### 2.4 Model Deployment & Inference

This is heavily tested. Know all 4 endpoint types cold.

#### Real-Time Inference
- Persistent endpoint, always on
- Low latency (milliseconds)
- Use for: interactive apps, APIs, real-time predictions
- Supports auto-scaling

#### Serverless Inference
- No instance management, scales to zero
- Cold start latency possible
- Use for: spiky/unpredictable traffic, infrequent requests
- Cost-effective for low-volume workloads

#### Asynchronous Inference
- Queued requests, results stored in S3
- Use for: large payloads (up to 1GB), long processing times
- Supports auto-scaling to zero when idle

#### Batch Transform
- Run predictions on entire datasets (no endpoint needed)
- Input from S3, output to S3
- Use for: offline scoring, preprocessing large datasets

**Exam tip — Decision tree:**
```
Need real-time response?
  → Yes, always-on traffic → Real-Time Inference
  → Yes, spiky/low traffic → Serverless Inference
  → No, large payload or long processing → Async Inference
  → No, bulk dataset scoring → Batch Transform
```

#### Multi-Model Endpoints (MME)
- Host multiple models on a single endpoint
- Models loaded/unloaded dynamically from S3
- Cost-efficient when models share the same framework

#### Multi-Container Endpoints
- Run different containers on one endpoint
- Serial inference pipeline (container A → container B)

---

### 2.5 MLOps — Pipelines, Registry & Automation

#### SageMaker Pipelines
- Native CI/CD for ML workflows
- DAG-based pipeline definition (Python SDK)
- Steps: Processing, Training, Tuning, Transform, Register, Condition, Lambda, Callback
- Integrates with EventBridge for triggers
- Tracks lineage automatically

#### SageMaker Model Registry
- Centralized catalog for trained models
- **Model Groups** — collection of model versions for a specific use case
- **Model Packages** — individual versioned model artifacts
- Approval workflow: Pending → Approved → Rejected
- Approved models can be auto-deployed via Pipelines

#### SageMaker Projects
- MLOps templates using Service Catalog
- Pre-built templates for: build/train/deploy, third-party Git, A/B testing
- Provisions CodePipeline, CodeBuild, CodeCommit automatically

#### SageMaker Experiments
- Track, compare, and analyze training runs
- Automatically captures metrics, parameters, artifacts
- Integrates with Studio for visualization

---

### 2.6 Monitoring & Observability

#### SageMaker Model Monitor
Four types of monitoring — know all of them:

| Monitor Type | What it detects |
|-------------|----------------|
| **Data Quality Monitor** | Feature drift vs training baseline |
| **Model Quality Monitor** | Prediction quality degradation (requires ground truth) |
| **Bias Drift Monitor** | Changes in model fairness over time |
| **Feature Attribution Drift** | Changes in SHAP-based feature importance |

- Monitoring schedules run on a cron
- Violations reported to CloudWatch and S3
- Baseline created from training data using `suggest_baseline()`

#### SageMaker Clarify
- Detects bias in data and models
- Explains model predictions (SHAP values)
- Pre-training bias metrics: Class Imbalance (CI), Difference in Proportions of Labels (DPL)
- Post-training bias metrics: DPPL, DI, DCO, RD, DAR, DRR, AD, CDDPL, TE, FT
- **Exam tip:** Clarify is used for explainability and bias detection. Model Monitor uses Clarify under the hood for bias/attribution drift.

---

### 2.7 Security

These topics appear across all domains:

- **IAM Roles** — SageMaker execution role needs S3, ECR, CloudWatch permissions
- **VPC** — Run training/inference inside a VPC for network isolation
- **Encryption** — Data at rest (KMS), data in transit (TLS)
- **SageMaker Role Manager** — Simplified role creation for ML personas
- **Network Isolation** — Containers with no internet access
- **Inter-Container Traffic Encryption** — For distributed training jobs
- **SageMaker Ground Truth** — Data labeling with human reviewers + active learning

---

## Phase 3 — Adjacent AWS Services (Week 6)

These appear alongside SageMaker in exam questions:

| Service | Role in ML |
|---------|-----------|
| **Amazon Bedrock** | Managed GenAI — foundation models, fine-tuning, RAG |
| **AWS Glue** | Large-scale ETL, data catalog, Spark jobs |
| **Amazon Athena** | SQL queries on S3 data |
| **Amazon Redshift** | Data warehouse, ML with Redshift ML |
| **AWS Step Functions** | Orchestrate ML workflows (alternative to Pipelines) |
| **Amazon Comprehend** | NLP — sentiment, entity recognition, PII redaction |
| **Amazon Rekognition** | Image/video analysis |
| **Amazon Forecast** | Managed time-series forecasting |
| **Amazon Personalize** | Managed recommendation engine |
| **AWS Lake Formation** | Data lake governance and access control |
| **Amazon EventBridge** | Event-driven triggers for ML pipelines |
| **AWS CodePipeline/CodeBuild** | CI/CD for model deployment |

---

## Phase 4 — Hands-On Practice (Week 7)

Don't skip this — the exam has scenario-based questions that require practical understanding.

### Labs to complete (in order):

1. **Set up SageMaker Studio** — create domain, user profile, launch Studio
2. **Data Wrangler flow** — import CSV from S3, apply transforms, export to notebook
3. **Training Job** — train XGBoost on a tabular dataset (use built-in algorithm)
4. **HPO Job** — run automatic model tuning on the trained model
5. **Real-Time Endpoint** — deploy model, invoke with boto3
6. **Batch Transform** — run batch predictions on a test dataset
7. **Model Monitor** — set up data quality monitoring on an endpoint
8. **SageMaker Pipeline** — build a pipeline with Processing → Training → Register steps
9. **Model Registry** — register a model, approve it, deploy approved version
10. **SageMaker Clarify** — run bias detection on training data

### Free resources for hands-on:
- [AWS SageMaker Immersion Day](https://catalog.workshops.aws/sagemaker-immersion-day) — free workshop labs
- [AWS Skill Builder](https://skillbuilder.aws) — free tier includes SageMaker getting started courses
- AWS Free Tier — SageMaker Studio has limited free usage for new accounts

---

## Phase 5 — Exam Prep (Week 8)

### Review checklist

- [ ] All 4 inference endpoint types and when to use each
- [ ] Data Wrangler vs Glue vs Processing Jobs — when to use which
- [ ] Feature Store online vs offline
- [ ] All 4 Model Monitor types
- [ ] SageMaker Pipelines step types
- [ ] Model Registry approval workflow
- [ ] Built-in algorithms and their use cases
- [ ] Distributed training: data parallelism vs model parallelism
- [ ] HPO strategies: Bayesian vs Random vs Grid vs Hyperband
- [ ] Security: VPC, KMS, IAM roles, network isolation
- [ ] Clarify bias metrics (pre-training vs post-training)
- [ ] Bedrock basics: foundation models, fine-tuning, RAG with Knowledge Bases
- [ ] Comprehend: sentiment, entities, PII detection

### Practice exams
- [AWS Skill Builder — Official Practice Question Set](https://skillbuilder.aws) (free, ~20 questions)
- [Whizlabs MLA-C01](https://www.whizlabs.com) — full practice tests
- [Udemy — Stephane Maarek / TutorialsDojo](https://www.udemy.com) — most popular prep courses
- [TutorialsDojo Cheat Sheets](https://tutorialsdojo.com) — great for last-minute review

### Exam day tips
- Read every question fully — AWS loves "most cost-effective" or "least operational overhead" qualifiers
- Eliminate obviously wrong answers first
- For scenario questions: identify the bottleneck (data prep? training? inference? monitoring?) then match to the right SageMaker tool
- Case study questions share context — read the scenario once, answer all related questions together
- Flag uncertain questions and come back — 170 minutes is enough time

---

## Quick Reference — SageMaker Tool Decision Map

```
Data is raw/unclean
  → Small/medium, GUI preferred     → Data Wrangler
  → Large scale ETL                 → AWS Glue
  → Custom script                   → Processing Job

Need to train a model
  → Tabular data                    → XGBoost (built-in)
  → Time series                     → DeepAR
  → NLP                             → BlazingText
  → Images                          → Image Classification / Object Detection
  → Custom model                    → Bring your own container (BYOC)

Need to tune hyperparameters
  → Efficient search                → Bayesian (AMT)
  → Parallel, fast                  → Hyperband

Need to deploy
  → Always-on, low latency          → Real-Time Endpoint
  → Spiky traffic, cost-sensitive   → Serverless Endpoint
  → Large payload / async           → Async Endpoint
  → Batch dataset                   → Batch Transform

Need to monitor
  → Feature distribution shift      → Data Quality Monitor
  → Prediction accuracy drop        → Model Quality Monitor
  → Fairness changes                → Bias Drift Monitor
  → Feature importance shift        → Feature Attribution Monitor

Need to explain predictions
  → SHAP values / bias report       → SageMaker Clarify

Need to automate the full workflow
  → ML-native DAG                   → SageMaker Pipelines
  → General AWS orchestration       → Step Functions

Need to manage model versions
  → Versioning + approval           → Model Registry
```

---

## Recommended Study Schedule (8 Weeks)

| Week | Focus |
|------|-------|
| 1 | ML fundamentals + AWS prerequisites (IAM, S3, VPC) |
| 2 | SageMaker Studio, Notebooks, Canvas, Domains |
| 3 | Data Wrangler, Processing Jobs, Feature Store |
| 4 | Training Jobs, Built-in Algorithms, HPO, Distributed Training |
| 5 | All 4 Inference types + Model Registry + Pipelines |
| 6 | Model Monitor, Clarify, Security, Adjacent AWS services |
| 7 | Hands-on labs (all 10 labs listed above) |
| 8 | Practice exams, review weak areas, cheat sheet review |

---

*Sources: [AWS MLA-C01 Exam Guide](https://aws.amazon.com/certification/certified-machine-learning-engineer-associate/) | [Pluralsight MLA-C01 Guide](https://www.pluralsight.com/resources/blog/cloud/MLA-C01-AWS-machine-learning-engineer-associate) | [AWS SageMaker Training Guide](https://aws.amazon.com/blogs/training-and-certification/building-ml-excellence-a-practical-training-guide-for-amazon-sagemaker-ai/)*
