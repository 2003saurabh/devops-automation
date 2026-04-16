# HireMeClub Backend — AWS Deployment & Migration Architecture Document

**Project:** HireMeClub Website Backend  
**Application:** Node.js / Express REST API  
**Domain:** `api.hiremeclub.com`  
**Region:** `ap-south-1` (Mumbai)  
**Document Type:** Deployment Architecture & Migration Reference  

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture Diagram](#2-architecture-diagram)
3. [Infrastructure Components](#3-infrastructure-components)
   - 3.1 [VPC & Networking](#31-vpc--networking)
   - 3.2 [EC2 Instance](#32-ec2-instance)
   - 3.3 [Application Load Balancer (ALB)](#33-application-load-balancer-alb)
   - 3.4 [SSL/TLS & DNS](#34-ssltls--dns)
   - 3.5 [Amazon ECR](#35-amazon-ecr)
   - 3.6 [Amazon S3](#36-amazon-s3)
   - 3.7 [CloudWatch Logging](#37-cloudwatch-logging)
4. [Application Stack](#4-application-stack)
5. [Containerization](#5-containerization)
   - 5.1 [Dockerfile](#51-dockerfile)
   - 5.2 [Docker Compose](#52-docker-compose)
6. [CI/CD Pipeline](#6-cicd-pipeline)
   - 6.1 [Pipeline Overview](#61-pipeline-overview)
   - 6.2 [Build & Push Stage](#62-build--push-stage)
   - 6.3 [Deploy Stage](#63-deploy-stage)
   - 6.4 [Health Check & Rollback](#64-health-check--rollback)
7. [Deployment Flow (Step-by-Step)](#7-deployment-flow-step-by-step)
8. [Secrets & Environment Variables](#8-secrets--environment-variables)
9. [Security Considerations](#9-security-considerations)
10. [Migration Steps Performed](#10-migration-steps-performed)
11. [Known Limitations & Recommendations](#11-known-limitations--recommendations)

---

## 1. Overview

This document describes the complete AWS deployment architecture for the HireMeClub backend API. The application is a Node.js/Express server containerized with Docker and deployed on an EC2 instance behind an Application Load Balancer (ALB). The entire deployment lifecycle is automated via a GitHub Actions CI/CD pipeline that builds Docker images, pushes them to Amazon ECR, and deploys to EC2 using AWS Systems Manager (SSM) — with no direct SSH access required.

---

## 2. Architecture Diagram

```
                          ┌─────────────────────────────────────────────────────┐
                          │                    AWS Cloud (ap-south-1)            │
                          │                                                       │
  Internet                │  ┌──────────────────────────────────────────────┐   │
  ─────────               │  │              VPC (10.0.0.0/16)               │   │
  User/Client             │  │                                              │   │
      │                   │  │  ┌──────────────────────────────────────┐   │   │
      │  HTTPS (443)       │  │  │   Public Subnet 1 (10.0.1.0/24)     │   │   │
      ▼                   │  │  │   AZ: ap-south-1a                    │   │   │
  ┌───────────┐           │  │  │                                      │   │   │
  │  Route 53 │           │  │  │  ┌──────────────────────────────┐   │   │   │
  │  Hosted   │──────────►│  │  │  │  Application Load Balancer   │   │   │   │
  │  Zone     │           │  │  │  │  (ALB)                       │   │   │   │
  │api.hireme │           │  │  │  │  Listener: HTTPS 443         │   │   │   │
  │club.com   │           │  │  │  │  SSL: ACM Certificate        │   │   │   │
  └───────────┘           │  │  │  └──────────────┬───────────────┘   │   │   │
                          │  │  │                 │                    │   │   │
                          │  │  │  ┌──────────────▼───────────────┐   │   │   │
                          │  │  │  │       Target Group           │   │   │   │
                          │  │  │  │  Protocol: HTTP              │   │   │   │
                          │  │  │  │  Port: 8080                  │   │   │   │
                          │  │  │  └──────────────┬───────────────┘   │   │   │
                          │  │  │                 │                    │   │   │
                          │  │  │  ┌──────────────▼───────────────┐   │   │   │
                          │  │  │  │   EC2 (t3.medium)            │   │   │   │
                          │  │  │  │   Ubuntu                     │   │   │   │
                          │  │  │  │   ┌──────────────────────┐   │   │   │   │
                          │  │  │  │   │  Docker Container    │   │   │   │   │
                          │  │  │  │   │  hiremeclub-app      │   │   │   │   │
                          │  │  │  │   │  Port: 8080          │   │   │   │   │
                          │  │  │  │   └──────────────────────┘   │   │   │   │
                          │  │  │  └──────────────────────────────┘   │   │   │
                          │  │  └──────────────────────────────────────┘   │   │
                          │  │                                              │   │
                          │  │  ┌──────────────────────────────────────┐   │   │
                          │  │  │   Public Subnet 2 (ALB requirement)  │   │   │
                          │  │  │   AZ: ap-south-1b                    │   │   │
                          │  │  └──────────────────────────────────────┘   │   │
                          │  └──────────────────────────────────────────────┘   │
                          │                                                       │
                          │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
                          │  │   ECR    │  │    S3    │  │   CloudWatch     │  │
                          │  │ (Images) │  │ (Assets) │  │   (Logs)         │  │
                          │  └──────────┘  └──────────┘  └──────────────────┘  │
                          └─────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────────────┐
  │                         GitHub Actions CI/CD                                  │
  │  Push to dev ──► Build Docker Image ──► Push to ECR ──► Deploy via SSM      │
  └──────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Infrastructure Components

### 3.1 VPC & Networking

The network foundation is provisioned via CloudFormation (`vpc.yml`).

| Resource | Details |
|---|---|
| VPC CIDR | `10.0.0.0/16` |
| Public Subnet 1 | `10.0.1.0/24` — hosts EC2 + ALB |
| Public Subnet 2 | Additional subnet in a second AZ (required by ALB for multi-AZ) |
| Internet Gateway | Attached to VPC, enables outbound internet access |
| Route Table | Default route `0.0.0.0/0` → Internet Gateway |
| DNS Support | Enabled (`EnableDnsSupport: true`, `EnableDnsHostnames: true`) |

The VPC CloudFormation stack exports `VPCId` and `SubnetId` as stack outputs for cross-stack reference.

**Why a second public subnet?**  
AWS ALB requires at least two subnets in different Availability Zones. A second public subnet was manually created in `ap-south-1b` to satisfy this requirement.

---

### 3.2 EC2 Instance

| Property | Value |
|---|---|
| Instance Type | `t3.medium` (2 vCPU, 4 GB RAM) |
| OS | Ubuntu |
| Placement | Public Subnet 1 |
| IAM Role | Must have: `AmazonSSMManagedInstanceCore`, `AmazonEC2ContainerRegistryReadOnly`, `CloudWatchLogsFullAccess` |
| Access Method | AWS SSM Session Manager (no SSH key required) |
| Software | Docker, Docker Compose, AWS CLI |

The EC2 instance runs the application as a Docker container managed by Docker Compose. The git repository is cloned at `/home/ubuntu/websit-backend` and the `.env` file is maintained there.

---

### 3.3 Application Load Balancer (ALB)

| Property | Value |
|---|---|
| Type | Application Load Balancer (internet-facing) |
| Subnets | Public Subnet 1 + Public Subnet 2 (two AZs) |
| Listener | HTTPS on port 443 with ACM SSL certificate |
| Target Group | HTTP on port 8080 → EC2 instance |
| Health Check | `GET /` on port 8080 |

Traffic flow: `Client → Route 53 → ALB (HTTPS 443) → Target Group → EC2:8080 → Docker Container`

---

### 3.4 SSL/TLS & DNS

| Service | Configuration |
|---|---|
| AWS Certificate Manager (ACM) | SSL certificate issued for `api.hiremeclub.com` |
| Route 53 Hosted Zone | `hiremeclub.com` |
| DNS Record | `api.hiremeclub.com` → CNAME/A-alias → ALB DNS name |

SSL is terminated at the ALB. Traffic between ALB and EC2 runs over HTTP on port 8080 within the VPC.

---

### 3.5 Amazon ECR

Docker images are stored in Amazon Elastic Container Registry.

| Property | Value |
|---|---|
| Repository | Configured via `ECR_REPOSITORY` secret |
| Image Tagging | `<registry>/<repo>:<git-sha>` + `latest` tag |
| Build Cache | Registry-based cache using `<repo>:cache` tag |
| Platform | `linux/amd64` (explicit for cross-platform builds) |

---

### 3.6 Amazon S3

The application uses S3 for file storage (logos and resumes), managed via the AWS SDK.

| File | Purpose |
|---|---|
| `AWS/logoS3.js` | Employer logo uploads |
| `AWS/resumeS3.js` | Candidate resume uploads |
| `AWS/s3.js` | Shared S3 client configuration |

---

### 3.7 CloudWatch Logging

Container logs are shipped directly to CloudWatch via the Docker `awslogs` log driver.

| Property | Value |
|---|---|
| Log Group | `/hiremeclub/prod/website-backend` |
| Log Stream | `app` |
| Region | `ap-south-1` |
| Auto-create Group | Enabled (`awslogs-create-group: "true"`) |

The CI/CD pipeline also ensures the log group exists before deployment (`aws logs create-log-group`).

---

## 4. Application Stack

| Layer | Technology |
|---|---|
| Runtime | Node.js 20 (Alpine) |
| Framework | Express.js |
| Database | MongoDB (via Mongoose) |
| Auth | JWT + Cookie-based sessions |
| File Storage | AWS S3 (multer-s3) |
| Email | Nodemailer |
| Process Manager | Tini (PID 1 signal handling) |
| API Prefix | `/api/v1` |
| Port | `8080` (configurable via `PORT` env var) |

Key routes registered in `app.js`:
- `/api/v1` — Candidate list, auth, employer auth, employer list, admin, CRM

---

## 5. Containerization

### 5.1 Dockerfile

The Dockerfile uses a **multi-stage build** for a lean production image.

```
Stage 1 (builder):  node:20-alpine
  └── npm ci --omit=dev   (production deps only)

Stage 2 (production): node:20-alpine
  ├── Install: wget (healthcheck), tini (PID 1)
  ├── Create non-root user: appuser:appgroup
  ├── Copy node_modules from builder
  ├── Copy application source
  ├── EXPOSE 8080
  ├── ENTRYPOINT: tini
  └── CMD: node app.js
```

Security practices applied:
- Non-root user (`appuser`)
- `no-new-privileges` security option
- Minimal Alpine base image
- Production-only dependencies

### 5.2 Docker Compose

`docker-compose.yml` manages the single application container.

| Setting | Value |
|---|---|
| Container Name | `hiremeclub-app` |
| Image | `${ECR_IMAGE}` (injected from `.env` by CI/CD) |
| Restart Policy | `unless-stopped` |
| Port Mapping | `8080:8080` |
| Volume | `uploads_data:/app/uploads` (persistent uploads) |
| Network | `hiremeclub-net` (bridge) |
| Log Driver | `awslogs` → CloudWatch |
| Health Check | `wget -qO- http://localhost:8080/` every 30s |
| Stop Grace Period | 30 seconds (graceful shutdown) |

---

## 6. CI/CD Pipeline

Pipeline file: `.github/workflows/cicd.yml`

### 6.1 Pipeline Overview

```
Trigger: Push to `dev` branch  OR  Manual (workflow_dispatch)
         │
         ▼
┌─────────────────────┐
│  Job 1: Build & Push │
│  Runner: ubuntu-latest│
│  1. Checkout code    │
│  2. Configure AWS    │
│  3. Login to ECR     │
│  4. Docker Buildx    │
│  5. Build & Push     │
│     image to ECR     │
│  Output: image_tag   │
└──────────┬──────────┘
           │  needs: build-and-push
           ▼
┌─────────────────────┐
│  Job 2: Deploy       │
│  Runner: ubuntu-latest│
│  1. Configure AWS    │
│  2. Build deploy     │
│     script (Python)  │
│  3. Send via SSM     │
│  4. Poll for status  │
└─────────────────────┘
```

**Concurrency control:** `group: deploy-production` with `cancel-in-progress: true` ensures only one deployment runs at a time.

---

### 6.2 Build & Push Stage

- Uses `docker buildx` with `--platform linux/amd64` for consistent builds
- Registry-based layer caching (`type=registry`) speeds up subsequent builds
- Image is tagged with both the git commit SHA and `latest`
- The commit SHA tag is passed as an output to the deploy job

---

### 6.3 Deploy Stage

Deployment is executed via **AWS SSM Run Command** — no SSH, no bastion host.

The deploy script runs 7 steps on the EC2 instance:

| Step | Action |
|---|---|
| 1 | Login to ECR |
| 2 | Ensure CloudWatch log group exists |
| 3 | Save current running image tag for rollback |
| 4 | Pull new Docker image from ECR |
| 5 | Update `ECR_IMAGE` in `/home/ubuntu/websit-backend/.env` |
| 6 | `docker compose up -d --pull never --remove-orphans` |
| 7 | Health check loop (12 × 10s = 2 minutes max) |

The script is base64-encoded before being sent via SSM to avoid shell escaping issues.

---

### 6.4 Health Check & Rollback

After bringing up the new container, the pipeline polls Docker's health status for up to 2 minutes.

```
New container healthy?
    YES → Prune dangling images → Deploy complete ✓
    NO  → Rollback image available?
              YES → Restore previous ECR_IMAGE in .env
                    → docker compose up with old image
                    → Poll rollback health (6 × 10s)
                    → Healthy? → Exit 0 ✓
                    → Not healthy? → Exit 1 ✗ (manual intervention)
              NO  → Exit 1 ✗ (manual intervention required)
```

---

## 7. Deployment Flow (Step-by-Step)

This section documents the exact sequence of steps followed to set up the production environment.

```
Step 1: Network Setup
  └── Deploy vpc.yml via CloudFormation
      ├── VPC: 10.0.0.0/16
      ├── Public Subnet 1: 10.0.1.0/24 (ap-south-1a)
      ├── Internet Gateway + Route Table
      └── Manually create Public Subnet 2 (ap-south-1b) for ALB

Step 2: EC2 Provisioning
  └── Launch t3.medium in Public Subnet 1
      ├── Attach IAM role (SSM + ECR + CloudWatch)
      ├── Install Docker, Docker Compose, AWS CLI
      └── Clone repo: git clone <repo> /home/ubuntu/websit-backend

Step 3: Containerize & Test Locally on EC2
  └── Build Docker image on EC2
      ├── Create .env file with all environment variables
      └── docker compose up -d (initial test)

Step 4: ECR Setup
  └── Create ECR repository
      └── Push initial image manually (or via pipeline)

Step 5: Load Balancer Setup
  ├── Create Target Group (HTTP, port 8080, health check: GET /)
  ├── Register EC2 instance in Target Group
  └── Create ALB (internet-facing)
      ├── Attach both public subnets
      └── Add HTTPS listener (port 443)

Step 6: SSL Certificate
  └── Request certificate in ACM for api.hiremeclub.com
      └── Validate via DNS (Route 53 CNAME record auto-created)

Step 7: DNS Configuration
  └── Route 53 Hosted Zone: hiremeclub.com
      └── Create A-record (alias) or CNAME:
          api.hiremeclub.com → ALB DNS name

Step 8: CI/CD Pipeline
  └── Add GitHub Secrets:
      ├── AWS_ACCESS_KEY_ID
      ├── AWS_SECRET_ACCESS_KEY
      ├── AWS_REGION
      ├── ECR_REGISTRY
      ├── ECR_REPOSITORY
      └── EC2_INSTANCE_ID
  └── Push to dev branch → pipeline triggers automatically
```

---

## 8. Secrets & Environment Variables

### GitHub Actions Secrets

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key for CI/CD |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `AWS_REGION` | AWS region (e.g., `ap-south-1`) |
| `ECR_REGISTRY` | ECR registry URL (e.g., `<account>.dkr.ecr.ap-south-1.amazonaws.com`) |
| `ECR_REPOSITORY` | ECR repository name |
| `EC2_INSTANCE_ID` | Target EC2 instance ID (e.g., `i-0abc123...`) |

### Application `.env` on EC2

The `.env` file at `/home/ubuntu/websit-backend/.env` must contain:

| Variable | Description |
|---|---|
| `PORT` | Application port (default: `8080`) |
| `MONGO_URL` | MongoDB connection string |
| `ECR_IMAGE` | Auto-updated by CI/CD pipeline on each deploy |
| JWT secrets, S3 bucket names, SMTP credentials, etc. | Application-specific config |

> **Note:** `ECR_IMAGE` is automatically updated by the deploy script on every deployment. Do not manually edit this value.

---

## 9. Security Considerations

| Area | Implementation |
|---|---|
| No SSH access | EC2 accessed exclusively via AWS SSM |
| Non-root container | Docker runs as `appuser` (non-root) |
| No new privileges | `security_opt: no-new-privileges:true` |
| SSL termination | HTTPS enforced at ALB via ACM certificate |
| IAM least privilege | CI/CD IAM user should have only required permissions |
| Secrets management | All secrets stored in GitHub Actions Secrets, never in code |
| Image scanning | Consider enabling ECR image scanning on push |
| VPC isolation | Application runs inside a dedicated VPC |

---

## 10. Migration Steps Performed

Summary of the complete migration from local/undeployed to production AWS:

1. **VPC provisioned** via CloudFormation (`vpc.yml`) with parameterized CIDR, subnet, IGW, and route table
2. **Second public subnet** manually created in a different AZ to satisfy ALB multi-AZ requirement
3. **EC2 instance** (`t3.medium`) launched in the public subnet with appropriate IAM role
4. **Git repository cloned** on EC2 at `/home/ubuntu/websit-backend`
5. **Application dockerized** using multi-stage Dockerfile; tested with Docker Compose on EC2
6. **Target Group** created pointing to EC2 on port 8080 with health check on `GET /`
7. **ALB created** (internet-facing) spanning both public subnets, with HTTPS listener on port 443
8. **SSL certificate** provisioned via ACM for `api.hiremeclub.com`, validated via Route 53 DNS
9. **Route 53 DNS record** created: `api.hiremeclub.com` → ALB DNS name
10. **ECR repository** created; Docker image pushed with git SHA tagging
11. **CI/CD pipeline** configured in `.github/workflows/cicd.yml` with GitHub Secrets; automated build → push → deploy on every push to `dev` branch

---

## 11. Known Limitations & Recommendations

| Area | Current State | Recommendation |
|---|---|---|
| Single EC2 instance | No redundancy; single point of failure | Consider Auto Scaling Group with min 2 instances |
| Public subnet for EC2 | EC2 is directly in a public subnet | Move EC2 to private subnet; ALB remains public |
| No WAF | ALB has no Web Application Firewall | Add AWS WAF to ALB for DDoS/injection protection |
| Manual .env management | `.env` file manually maintained on EC2 | Migrate secrets to AWS Secrets Manager or Parameter Store |
| No private subnet | All resources in public subnets | Add private subnets + NAT Gateway for EC2 |
| Single AZ EC2 | EC2 only in one AZ | Multi-AZ deployment for high availability |
| No database backup automation | MongoDB backup not documented | Set up automated MongoDB Atlas backups or EBS snapshots |
| ECR image retention | No lifecycle policy mentioned | Add ECR lifecycle policy to limit stored image count |
| HTTP between ALB and EC2 | Internal traffic is unencrypted | Acceptable within VPC; optionally enable HTTPS on EC2 |
