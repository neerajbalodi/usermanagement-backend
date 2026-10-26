# Infra pipeline – EKS (Day 4)

This folder creates the **platform** the app runs on. It is its own Jenkins job (`um-infra`),
separate from the app pipelines (`um-backend`, `um-frontend`).

| What | Where |
|---|---|
| VPC, EKS cluster + nodes, ECR repos, S3 photos bucket, IAM roles for pods | `terraform/` |
| Namespace, disk type (gp3), PostgreSQL, Redis | `k8s/` |
| metrics-server (for HPA), Cluster Autoscaler (adds/removes nodes) | installed by the `Jenkinsfile` |
| Config (`um-config`) and passwords (`um-secrets`) | created by the `Jenkinsfile` |

Terraform state is stored in S3 (`um-tfstate-<account>-<region>`), created automatically on the first run.

## One-time setup

1. **Tools on the Jenkins server:** `bash infra-eks/jenkins/install-tools.sh`
   (Docker, AWS CLI v2, kubectl 1.35, Helm, then restarts Jenkins).
2. **AWS permissions:** `jenkins-ec2-role` already has `AmazonEC2FullAccess`,
   `AmazonS3FullAccess`, `IAMFullAccess` (Day 1–3). Add:
   IAM → Roles → `jenkins-ec2-role` → Add permissions → **Create inline policy** → JSON →
   paste `jenkins/jenkins-eks-policy.json` → name it `jenkins-eks-ecr`.
3. **Jenkins credentials** (same as Day 3): Secret text `um-db-password` and `um-redis-password`.
4. **Jenkins job:** New Item → `um-infra` → Pipeline → *Pipeline script from SCM* →
   Git `https://github.com/neerajbalodi/usermanagement-backend.git`, branch `*/day-4`,
   **Script Path `infra-eks/Jenkinsfile`**.

## Run

- **Build with Parameters → `apply`**: first time ≈ 20 min (the EKS control plane takes ~12),
  afterwards ≈ 2 min. Ends with "INFRA READY".
- Then run the app pipelines:
  - **`um-backend`**: repo `usermanagement-backend`, branch `*/day-4`, Script Path `Jenkinsfile`
  - **`um-frontend`**: repo `usermanagement-frontend`, branch `*/day-4`, Script Path `Jenkinsfile`

  Each one: build image → push to ECR → deploy → wait for the rolling update → verify.
  The frontend job prints the public URL of the app.
- **`destroy`** at the end of the day: removes the app from the cluster first (so the load
  balancer and disks are deleted), then everything Terraform created.
  The small state bucket is kept for next time.

## Cost (approx., ap-south-1)
EKS control plane $0.10/h + NAT gateway $0.045/h + 2 × t3.medium + load balancer
≈ **$0.30 per hour**. Always run `destroy` after class.

## Using kubectl yourself (optional)
On the Jenkins server: `sudo -u jenkins kubectl --kubeconfig /var/lib/jenkins/workspace/um-infra/.kubeconfig get pods -A`.
From your laptop: set the Terraform variable `admin_principal_arn` to your IAM user ARN, re-run
`apply`, then `aws eks update-kubeconfig --name um-eks --region ap-south-1`.
