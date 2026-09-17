# Cost Estimate
## AWS SAA Graduation Project — Scalable E-Commerce Web Application
**Author**: Aziz Benchikh | Region: us-east-1

---

> [!NOTE]
> All estimates below are **monthly costs** based on **AWS us-east-1 pricing (2024)**.
> Actual costs vary based on traffic, data transfer, and usage patterns.
> Use the [AWS Pricing Calculator](https://calculator.aws/pricing/2/home) to get an exact estimate.

---

## Scenario 1: Demo / Minimal (Free Tier + Low Cost)
*Purpose: Project demonstration, avoid real charges*

| Service | Configuration | Monthly Cost |
|---------|--------------|-------------|
| EC2 (2x t3.micro) | ~750 hrs/month × 2 = 1500 hrs | **$0** (Free Tier 750 hrs) |
| RDS (db.t3.micro, Single-AZ) | 730 hrs × $0.017/hr | **$12.41** |
| NAT Gateway (1x) | 730 hrs × $0.045 + minimal data | **$33.48** |
| ALB | 730 hrs × $0.008 + LCU | **$16.20** |
| CloudFront | Free tier: 1 TB transfer + 10M requests | **$0** |
| S3 (Static assets) | < 5 GB storage + minimal requests | **$0.12** |
| Route 53 | 1 hosted zone + health checks | **$0.50** |
| CloudWatch | Basic alarms (first 10 free) | **$0** |
| Secrets Manager | 1 secret × $0.40 | **$0.40** |
| **TOTAL** | | **~$63/month** |

> [!TIP]
> **To minimize costs for demo**: Use a single NAT Gateway, disable Multi-AZ RDS, and deploy for only a few hours before deleting the stack. Expected cost: < $5 for a 8-hour demo.

---

## Scenario 2: Best Practice Architecture (This Project)
*Purpose: Production-grade high availability — as designed*

| Service | Configuration | Monthly Cost |
|---------|--------------|-------------|
| EC2 (2x t3.micro, min) | 730 hrs × 2 × $0.0104/hr | **$15.18** |
| EC2 (scale-out, avg 2.5 instances) | Average 0.5 extra × 730 hrs | **$3.80** |
| RDS (db.t3.micro, **Multi-AZ**) | 730 hrs × $0.034/hr | **$24.82** |
| NAT Gateway (**2x**, one per AZ) | 2 × 730 hrs × $0.045 + data | **$65.70** |
| ALB | 730 hrs × $0.008 + LCU charges | **$18.25** |
| CloudFront | 10 TB data + 50M requests | **$0.93** |
| S3 (Static assets, Intelligent Tiering) | 50 GB × $0.023/GB | **$1.15** |
| Route 53 | 1 hosted zone + health checks (3) | **$3.00** |
| CloudWatch | 7 custom alarms + dashboard | **$5.10** |
| CloudWatch Logs | Nginx access/error logs | **$2.50** |
| Secrets Manager | 1 secret + API calls | **$0.40** |
| SSM Session Manager | VPC endpoints (3 × 2 AZs) | **$21.90** |
| KMS | 1 CMK + API calls | **$1.00** |
| **TOTAL** | | **~$163/month** |

---

## Scenario 3: Production Scale (High Traffic)
*For reference only — beyond project scope*

| Service | Configuration | Monthly Cost |
|---------|--------------|-------------|
| EC2 (6x t3.medium, avg) | 6 × 730 × $0.0416/hr | **$182.30** |
| RDS (db.r6g.large, Multi-AZ) | 730 × $0.48/hr | **$350.40** |
| NAT Gateway (2x, high transfer) | Base + 100 GB data/day | **$220.00** |
| ALB | High LCU count | **$45.00** |
| CloudFront | 100 TB data | **$8.50** |
| Other services | Logs, monitoring, etc. | **$50.00** |
| **TOTAL** | | **~$856/month** |

---

## Cost Optimization Tips (SAA-C03 Exam Topic)

| Strategy | Savings | How |
|----------|---------|-----|
| **S3 Intelligent-Tiering** | 30-50% on storage | Automatically moves infrequently accessed objects to cheaper tiers |
| **CloudFront caching** | Reduces ALB + EC2 costs | Static assets served from edge, fewer backend requests |
| **ASG Target Tracking** | 20-40% on compute | Scales in during off-peak hours automatically |
| **Reserved Instances** | 30-60% on EC2 | 1 or 3-year commitment for baseline capacity |
| **Compute Savings Plans** | Up to 66% on EC2 | Flexible pricing plan across instance families |
| **Single NAT GW (dev only)** | Saves ~$33/month | Acceptable for dev; use 2 for production HA |
| **S3 Lifecycle Policies** | 40-90% on old objects | Transition logs/backups to Glacier |
| **RDS Automated Backups** | No extra cost | Included in RDS pricing up to DB storage size |
| **SSM instead of Bastion** | Eliminates bastion EC2 cost | No extra instance needed for shell access |

---

## Free Tier Summary

The following services are **free** for 12 months (new AWS accounts):

| Service | Free Tier Limit |
|---------|----------------|
| EC2 t2.micro or t3.micro | 750 hours/month |
| RDS db.t3.micro | 750 hours/month |
| S3 | 5 GB storage, 20K GET requests |
| CloudFront | 1 TB data transfer, 10M HTTP requests |
| CloudWatch | 10 custom metrics, 10 alarms |
| SNS | 1 million publishes |

---

## Billing Alerts

Set up AWS billing alerts to avoid surprise charges:

1. Navigate to **AWS Billing → Budgets**
2. Create a **Monthly Cost Budget**: $50/month
3. Set alert at 80% threshold → email notification
4. Enable **Free Tier Usage Alerts** in billing preferences
