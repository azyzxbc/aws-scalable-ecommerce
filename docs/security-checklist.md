# Security Checklist
## AWS SAA Graduation Project — Scalable E-Commerce Web Application
**Author**: Aziz Benchikh
**Framework**: AWS Well-Architected Framework — Security Pillar

---

> [!NOTE]
> This checklist maps to the **SAA-C03 Security domain** and the **AWS Well-Architected Framework Security Pillar**. Each item demonstrates a security control implemented in this architecture.

---

## 1. Identity and Access Management (IAM)

| # | Control | Status | Implementation |
|---|---------|--------|---------------|
| 1.1 | No hardcoded credentials in code or templates | ✅ | AWS Secrets Manager generates & stores RDS password |
| 1.2 | EC2 uses IAM Instance Role (not access keys) | ✅ | `EC2InstanceRole` with least-privilege policies |
| 1.3 | IAM role follows least-privilege principle | ✅ | Only `secretsmanager:GetSecretValue` and SSM actions |
| 1.4 | MFA enabled on AWS root account | ⚠️ | Manual step — enable in IAM console |
| 1.5 | No root account usage for deployments | ✅ | Use IAM user/role with required permissions |
| 1.6 | IAM password policy enforced | ⚠️ | Set in IAM → Account Settings |

---

## 2. Network Security (Defense in Depth)

| # | Control | Status | Implementation |
|---|---------|--------|---------------|
| 2.1 | EC2 instances in private subnets | ✅ | `10.0.10.0/24`, `10.0.20.0/24` — no public IPs |
| 2.2 | RDS in isolated DB subnets | ✅ | `10.0.30.0/24`, `10.0.40.0/24` — no internet route |
| 2.3 | ALB is the only internet-facing resource | ✅ | ALB in public subnets; EC2 SG blocks direct access |
| 2.4 | Security Group chaining (least privilege) | ✅ | ALB SG → EC2 SG → RDS SG (port 80 → port 3306) |
| 2.5 | No 0.0.0.0/0 inbound to EC2 or RDS | ✅ | EC2 SG: only from ALB SG; RDS SG: only from EC2 SG |
| 2.6 | No SSH port (22) open anywhere | ✅ | Session Manager used instead — no bastion host |
| 2.7 | NAT Gateways for private subnet egress | ✅ | One NAT GW per AZ for outbound internet access |
| 2.8 | IMDSv2 enforced on EC2 | ✅ | `HttpTokens: required` in Launch Template |

---

## 3. Edge Protection

| # | Control | Status | Implementation |
|---|---------|--------|---------------|
| 3.1 | AWS WAF protecting against OWASP Top 10 | ✅ | WAF WebACL attached to CloudFront |
| 3.2 | AWS Shield Standard enabled | ✅ | Automatic for all AWS accounts — DDoS protection |
| 3.3 | HTTPS enforced (HTTP → HTTPS redirect) | ✅ | CloudFront ViewerProtocolPolicy: `redirect-to-https` |
| 3.4 | Minimum TLS 1.2 | ✅ | `MinimumProtocolVersion: TLSv1.2_2021` |
| 3.5 | Security response headers | ✅ | HSTS, X-Frame-Options, X-Content-Type-Options, CSP |
| 3.6 | Rate limiting on API | ✅ | WAF rate-based rules |
| 3.7 | CloudFront Origin Custom Header | ✅ | `X-CloudFront-Secret` header validates origin traffic |

---

## 4. Data Protection

| # | Control | Status | Implementation |
|---|---------|--------|---------------|
| 4.1 | RDS encrypted at rest | ✅ | KMS Customer-Managed Key with annual rotation |
| 4.2 | EBS (EC2 root volumes) encrypted | ✅ | `Encrypted: true` in Launch Template |
| 4.3 | S3 bucket encrypted at rest | ✅ | SSE-S3 (AES-256) on static assets bucket |
| 4.4 | S3 public access blocked | ✅ | All `BlockPublicAcls`, `BlockPublicPolicy` enabled |
| 4.5 | S3 access only via CloudFront OAC | ✅ | Origin Access Control — no direct S3 URL access |
| 4.6 | Encryption in transit (TLS) | ✅ | CloudFront HTTPS + RDS `require_secure_transport=ON` |
| 4.7 | RDS credentials auto-rotated | ⚙️ | Secrets Manager supports rotation — configure lambda |
| 4.8 | RDS backup encryption | ✅ | Automated backups inherit KMS key encryption |

---

## 5. Logging and Monitoring

| # | Control | Status | Implementation |
|---|---------|--------|---------------|
| 5.1 | CloudWatch alarms for key metrics | ✅ | CPU, unhealthy hosts, latency, 5xx errors, RDS |
| 5.2 | SNS email notifications on alarms | ✅ | SNS topic with email subscription |
| 5.3 | CloudWatch dashboard | ✅ | Executive overview of all key metrics |
| 5.4 | Nginx access logs shipped to CloudWatch | ✅ | CloudWatch agent configured in user data |
| 5.5 | RDS slow query & error logs to CloudWatch | ✅ | `EnableCloudwatchLogsExports: [error, slowquery]` |
| 5.6 | RDS Enhanced Monitoring (60s) | ✅ | OS-level metrics via monitoring role |
| 5.7 | RDS Performance Insights | ✅ | 7-day retention for query analysis |
| 5.8 | CloudTrail enabled (recommended) | ⚠️ | Enable manually in CloudTrail console — all API calls |
| 5.9 | AWS Config rules (recommended) | ⚠️ | Enable Config for compliance scanning |

---

## 6. Resilience and Availability

| # | Control | Status | Implementation |
|---|---------|--------|---------------|
| 6.1 | Multi-AZ deployment (2 AZs) | ✅ | Resources in `us-east-1a` and `us-east-1b` |
| 6.2 | RDS Multi-AZ automatic failover | ✅ | Standby replica with <2 min failover |
| 6.3 | Auto Scaling for EC2 | ✅ | ASG min=2, max=6 with target tracking |
| 6.4 | ALB health checks (ELB type) | ✅ | `/health` endpoint, 2 healthy → 5 unhealthy thresholds |
| 6.5 | CloudFront as CDN and failover | ✅ | Serves cached content during origin failures |
| 6.6 | RDS automated backups | ✅ | 7-day retention, 3 AM backup window |
| 6.7 | RDS Storage Auto Scaling | ✅ | Auto-scales to 100 GB when 10% free |
| 6.8 | Deletion protection on RDS | ⚙️ | Set `DeletionProtection: true` for production |

---

## 7. Secure Access to Instances

| # | Control | Status | Implementation |
|---|---------|--------|---------------|
| 7.1 | No SSH bastion host | ✅ | SSM Session Manager used exclusively |
| 7.2 | No EC2 key pair required | ✅ | Launch Template has no key pair |
| 7.3 | SSM VPC Interface Endpoints | ✅ | Traffic stays within VPC, no internet |
| 7.4 | Session Manager audit logs | ⚙️ | Enable in SSM Preferences → S3 logging |

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Implemented in CloudFormation templates |
| ⚠️ | Requires manual action in AWS Console |
| ⚙️ | Optional — recommended for production |

---

## Exam Mapping (SAA-C03 Security Domain)

| Exam Topic | Covered By |
|------------|-----------|
| Secure access to AWS resources | IAM Roles, SSM Session Manager |
| Secure workloads and applications | WAF, Security Groups, private subnets |
| Appropriate data security controls | KMS, Secrets Manager, S3 encryption |
| Detect and respond to security threats | CloudWatch alarms, GuardDuty (recommended) |
