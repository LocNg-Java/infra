# AWS Infrastructure Architecture

## Network Architecture Diagram

```mermaid
graph TB
    subgraph "AWS Cloud - Region: us-east-1"
        subgraph "VPC 10.0.0.0/16"
            IGW[Internet Gateway]

            subgraph "Availability Zone 1 - us-east-1a"
                subgraph "Public Subnet 10.0.1.0/24"
                    NAT1[NAT Gateway 1<br/>Elastic IP]
                    ALB1[Application Load Balancer<br/>HTTPS:443 / HTTP:80]
                end

                subgraph "Private Subnet 10.0.10.0/24"
                    Node1[EKS Worker Node 1<br/>EC2 t3.medium]
                    RDS1[(RDS PostgreSQL<br/>db.t3.micro<br/>Port: 5432)]

                    subgraph "Pods in Node 1"
                        Auth[Auth Service<br/>:8087]
                        Payment[Payment Service<br/>:8085]
                        Dashboard[K8s Dashboard<br/>UI]
                    end
                end
            end

            subgraph "Availability Zone 2 - us-east-1b"
                subgraph "Public Subnet 10.0.2.0/24"
                    NAT2[NAT Gateway 2<br/>Elastic IP]
                    ALB2[Application Load Balancer<br/>HTTPS:443 / HTTP:80]
                end

                subgraph "Private Subnet 10.0.11.0/24"
                    Node2[EKS Worker Node 2<br/>EC2 t3.medium]
                    RDS2[(RDS Standby<br/>Multi-AZ)]

                    subgraph "Pods in Node 2"
                        Order[Order Service<br/>:8086]
                        React[React Frontend<br/>:80]
                        Metrics[Metrics Server]
                    end
                end
            end
        end

        subgraph "EKS Control Plane - Managed by AWS"
            API[API Server]
            Scheduler[Scheduler]
            Controller[Controller Manager]
            OIDC[OIDC Provider<br/>IRSA]
        end

        subgraph "AWS Services - Regional"
            ECR[ECR Repositories<br/>- auth-service<br/>- order-service<br/>- payment-service<br/>- react-frontend]
            Secrets[Secrets Manager<br/>- RDS Credentials<br/>- API Keys]
            CW[CloudWatch<br/>- Logs<br/>- Metrics]

            subgraph "IAM"
                ClusterRole[EKS Cluster Role]
                NodeRole[Node Group Role]
                ALBRole[ALB Controller Role<br/>IRSA]
                SecretRole[Secrets Manager Role<br/>IRSA]
            end
        end
    end

    Internet((Internet<br/>Users))

    %% Connections
    Internet -->|HTTPS/HTTP| IGW
    IGW --> ALB1
    IGW --> ALB2
    ALB1 --> Node1
    ALB2 --> Node2
    Node1 --> NAT1
    Node2 --> NAT2
    NAT1 --> IGW
    NAT2 --> IGW

    Auth -.->|Read| Secrets
    Order -.->|Read| Secrets
    Payment -.->|Read| Secrets

    Auth -->|Query| RDS1
    Order -->|Query| RDS1
    Payment -->|Query| RDS1

    RDS1 -.->|Replication| RDS2

    Node1 -->|Pull Images| ECR
    Node2 -->|Pull Images| ECR

    Node1 -.->|Logs/Metrics| CW
    Node2 -.->|Logs/Metrics| CW

    API --> Node1
    API --> Node2

    OIDC -.->|Assume| ALBRole
    OIDC -.->|Assume| SecretRole

    style Internet fill:#e1f5ff
    style IGW fill:#ff9800
    style ALB1 fill:#4caf50
    style ALB2 fill:#4caf50
    style NAT1 fill:#ff9800
    style NAT2 fill:#ff9800
    style Node1 fill:#2196f3
    style Node2 fill:#2196f3
    style RDS1 fill:#9c27b0
    style RDS2 fill:#9c27b0
    style ECR fill:#f44336
    style Secrets fill:#795548
    style CW fill:#607d8b
    style API fill:#00bcd4
    style OIDC fill:#00bcd4
```

## Traffic Flow Diagram

```mermaid
sequenceDiagram
    participant User as Internet User
    participant IGW as Internet Gateway
    participant ALB as Application Load Balancer
    participant Pod as Service Pod<br/>(auth/order/payment)
    participant RDS as RDS PostgreSQL
    participant Secrets as Secrets Manager

    User->>IGW: HTTPS Request
    IGW->>ALB: Forward to ALB
    ALB->>Pod: Route to Pod (Private Subnet)
    Pod->>Secrets: Get DB Credentials (IRSA)
    Secrets-->>Pod: Return Credentials
    Pod->>RDS: Query Database
    RDS-->>Pod: Return Data
    Pod-->>ALB: Response
    ALB-->>IGW: Forward Response
    IGW-->>User: HTTPS Response
```

## CI/CD Flow Diagram

```mermaid
graph LR
    subgraph "Source Control"
        GH[GitHub Repository<br/>app/services/*]
    end

    subgraph "CI - Harness/GitHub Actions"
        Build[Build Docker Image<br/>Maven/npm]
        Test[Run Tests<br/>Unit + Integration]
        Scan[Security Scan<br/>Trivy/Snyk]
        Tag[Tag Image<br/>git-sha + latest]
    end

    subgraph "Container Registry"
        ECR1[ECR: auth-service]
        ECR2[ECR: order-service]
        ECR3[ECR: payment-service]
        ECR4[ECR: react-frontend]
    end

    subgraph "CD - Harness"
        Deploy[Deploy to EKS<br/>kubectl apply]
        Verify[Health Check<br/>Smoke Tests]
        Rollback[Rollback on Failure]
    end

    subgraph "EKS Cluster"
        Pods[Running Pods<br/>Deployment]
    end

    GH -->|Git Push| Build
    Build --> Test
    Test --> Scan
    Scan --> Tag
    Tag -->|Push| ECR1
    Tag -->|Push| ECR2
    Tag -->|Push| ECR3
    Tag -->|Push| ECR4

    ECR1 --> Deploy
    ECR2 --> Deploy
    ECR3 --> Deploy
    ECR4 --> Deploy

    Deploy --> Verify
    Verify -->|Success| Pods
    Verify -->|Failure| Rollback
    Rollback --> Pods

    style GH fill:#24292e
    style Build fill:#2088ff
    style ECR1 fill:#ff9900
    style ECR2 fill:#ff9900
    style ECR3 fill:#ff9900
    style ECR4 fill:#ff9900
    style Deploy fill:#00c853
    style Pods fill:#1976d2
```

## Component Details

### VPC Configuration
- **CIDR Block**: 10.0.0.0/16 (Dev), 10.1.0.0/16 (Prod)
- **Public Subnets**: 2 AZs (Dev) / 3 AZs (Prod)
  - Auto-assign public IPs
  - Tagged for ELB
- **Private Subnets**: 2 AZs (Dev) / 3 AZs (Prod)
  - No public IPs
  - Tagged for internal ELB
- **NAT Gateways**: One per AZ (HA)
- **Internet Gateway**: Single for VPC

### EKS Cluster
- **Control Plane**: Managed by AWS (Multi-AZ)
- **Node Group**:
  - Dev: 2-4 nodes (t3.medium)
  - Prod: 3-6 nodes (t3.large)
- **Networking**: VPC CNI plugin
- **OIDC Provider**: For IRSA

### RDS PostgreSQL
- **Instance**: db.t3.micro (Dev) / db.t3.small (Prod)
- **Storage**: 20GB (Dev) / 50GB (Prod) - Auto-scaling enabled
- **Backup**: 7 days retention
- **Multi-AZ**: Enabled for Prod
- **Encryption**: At rest & in transit
- **Access**: Private subnets only, via Security Groups

### ECR (Container Registry)
- **Repositories**: 4 (auth, order, payment, react-frontend)
- **Scanning**: Enabled on push
- **Lifecycle**: Keep last 10 images (Dev) / 20 (Prod)
- **Encryption**: AES256

### Security Groups

```mermaid
graph TD
    Internet[Internet<br/>0.0.0.0/0]

    subgraph "ALB Security Group"
        ALB_IN[Inbound Rules<br/>Port 80: HTTP<br/>Port 443: HTTPS<br/>Source: 0.0.0.0/0]
        ALB_OUT[Outbound Rules<br/>All Traffic<br/>Dest: EKS Nodes]
    end

    subgraph "EKS Node Security Group"
        NODE_IN[Inbound Rules<br/>From ALB SG: All Traffic<br/>From Self: All Traffic<br/>inter-node communication]
        NODE_OUT[Outbound Rules<br/>All Traffic<br/>Dest: 0.0.0.0/0 via NAT]
    end

    subgraph "RDS Security Group"
        RDS_IN[Inbound Rules<br/>Port 5432: PostgreSQL<br/>Source: EKS Node SG]
        RDS_OUT[Outbound Rules<br/>None]
    end

    Internet -->|HTTPS/HTTP| ALB_IN
    ALB_OUT --> NODE_IN
    NODE_OUT --> Internet
    NODE_IN -->|Port 5432| RDS_IN

    style ALB_IN fill:#4caf50
    style ALB_OUT fill:#8bc34a
    style NODE_IN fill:#2196f3
    style NODE_OUT fill:#64b5f6
    style RDS_IN fill:#9c27b0
    style RDS_OUT fill:#ba68c8
```

## IAM & IRSA (IAM Roles for Service Accounts)

```mermaid
graph TB
    subgraph "EKS Cluster"
        OIDC[OIDC Identity Provider<br/>Web Identity Federation]

        subgraph "kube-system namespace"
            ALB_SA[Service Account<br/>aws-load-balancer-controller]
        end

        subgraph "default namespace"
            APP_SA[Service Account<br/>app-service-account]
        end

        subgraph "Pods"
            ALB_POD[ALB Controller Pod]
            APP_POD[Application Pods<br/>auth/order/payment]
        end
    end

    subgraph "AWS IAM"
        ALB_ROLE[IAM Role<br/>ALB Controller<br/>- Create/Delete ALB<br/>- Manage Target Groups<br/>- Update Security Groups]

        SECRET_ROLE[IAM Role<br/>Secrets Manager Access<br/>- GetSecretValue<br/>- DescribeSecret]

        TRUST[Trust Policy<br/>OIDC Provider]
    end

    subgraph "AWS Resources"
        ALB_RES[Application Load Balancer<br/>Target Groups<br/>Security Groups]
        SECRETS[Secrets Manager<br/>RDS Credentials]
    end

    OIDC -->|Assume Role| TRUST
    TRUST --> ALB_ROLE
    TRUST --> SECRET_ROLE

    ALB_SA -.->|annotated with role ARN| ALB_ROLE
    APP_SA -.->|annotated with role ARN| SECRET_ROLE

    ALB_POD -->|uses| ALB_SA
    APP_POD -->|uses| APP_SA

    ALB_ROLE -->|Manage| ALB_RES
    SECRET_ROLE -->|Read| SECRETS

    style OIDC fill:#00bcd4
    style ALB_ROLE fill:#ff9800
    style SECRET_ROLE fill:#ff9800
    style TRUST fill:#ffc107
    style ALB_RES fill:#4caf50
    style SECRETS fill:#795548
```

## Kubernetes Dashboard Access Flow

```mermaid
sequenceDiagram
    participant Dev as Developer Workstation
    participant Proxy as kubectl proxy<br/>localhost:8001
    participant API as EKS API Server<br/>AWS IAM Auth
    participant SA as Service Account<br/>dashboard-admin
    participant Dashboard as Dashboard Pod<br/>kubernetes-dashboard
    participant Metrics as Metrics Server
    participant K8s as Kubernetes Resources<br/>Pods/Deployments/Services

    Dev->>Dev: 1. Configure kubectl<br/>aws eks update-kubeconfig
    Dev->>API: 2. Create token for SA<br/>kubectl create token
    API-->>Dev: Return JWT Token
    Dev->>Proxy: 3. Start proxy<br/>kubectl proxy
    Dev->>Proxy: 4. Access Dashboard URL<br/>with token
    Proxy->>API: Forward with auth
    API->>SA: Verify token & permissions
    SA->>Dashboard: Authorized access
    Dashboard->>Metrics: Get pod/node metrics
    Metrics-->>Dashboard: Return metrics
    Dashboard->>K8s: Query resources
    K8s-->>Dashboard: Return data
    Dashboard-->>Proxy: Render UI
    Proxy-->>Dev: Display in Browser

    Note over Dev,K8s: Full cluster-admin access via dashboard-admin SA
```

## Cost Breakdown (Dev Environment - Monthly)

| Service | Resource | Cost |
|---------|----------|------|
| EKS | Control Plane | $73 |
| EC2 | 2x t3.medium nodes | $60 |
| RDS | db.t3.micro | $15 |
| NAT Gateway | 2x NAT Gateway | $65 |
| Data Transfer | ~100GB | $9 |
| ECR | Storage | $1 |
| CloudWatch | Logs | $5 |
| **Total** | | **~$228/month** |

## High Availability Features

✅ **Multi-AZ**: Worker nodes & RDS across 2 AZs (Dev) / 3 AZs (Prod)
✅ **NAT Gateways**: One per AZ for redundancy
✅ **Auto Scaling**: Node group auto-scales based on load
✅ **Health Checks**: ALB health checks for pods
✅ **RDS Multi-AZ**: Automatic failover for Prod
✅ **Load Balancing**: ALB distributes traffic across AZs

## Security Features

✅ **Private Subnets**: All app workloads in private subnets
✅ **Security Groups**: Least-privilege network access
✅ **IRSA**: No AWS credentials in pods
✅ **Secrets Manager**: Encrypted credential storage
✅ **Encryption**: RDS, ECR, EBS all encrypted
✅ **HTTPS**: ALB terminates SSL/TLS
✅ **Dashboard Auth**: Token-based authentication

## Monitoring & Logging

- **CloudWatch Logs**: EKS control plane logs
- **Container Insights**: Node & pod metrics
- **Metrics Server**: In-cluster resource metrics
- **Dashboard**: Web UI for cluster visualization
- **RDS Monitoring**: Performance Insights enabled
