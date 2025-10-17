# Kubernetes Addons Module

This module installs essential Kubernetes addons on EKS cluster:

- **Kubernetes Dashboard**: Web-based UI for managing cluster resources
- **Metrics Server**: Collects resource metrics for HPA and kubectl top

## Features

- Automatic installation of Kubernetes Dashboard v2.7.0
- Metrics Server for resource monitoring
- Dashboard admin service account with cluster-admin privileges
- Token-based authentication

## Usage

```hcl
module "k8s_addons" {
  source = "../../modules/k8s-addons"

  cluster_id             = module.eks.cluster_id
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority_data
  enable_dashboard       = true
  enable_metrics_server  = true

  depends_on = [module.eks]
}
```

## Accessing the Dashboard

### Step 1: Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name eks-main-dev
```

### Step 2: Get Dashboard Token

```bash
kubectl -n kubernetes-dashboard create token dashboard-admin
```

Copy the token output.

### Step 3: Start kubectl Proxy

```bash
kubectl proxy
```

### Step 4: Access Dashboard

Open your browser and navigate to:
```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

Paste the token from Step 2.

## Alternative: Port Forward (without proxy)

```bash
kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443
```

Then access at: https://localhost:8443

## Metrics Server

After installation, you can use:

```bash
# View node metrics
kubectl top nodes

# View pod metrics
kubectl top pods -A

# View pod metrics in specific namespace
kubectl top pods -n default
```

## Security

The dashboard admin service account has `cluster-admin` role for full cluster access.

For production, consider:
- Creating limited-privilege service accounts
- Using RBAC to restrict access
- Implementing network policies
- Using AWS SSO/OIDC integration

## Troubleshooting

### Dashboard not accessible

Check if pods are running:
```bash
kubectl get pods -n kubernetes-dashboard
```

### Metrics not available

Check Metrics Server:
```bash
kubectl get deployment metrics-server -n kube-system
kubectl logs -n kube-system -l k8s-app=metrics-server
```

### Token expired

Generate a new token:
```bash
kubectl -n kubernetes-dashboard create token dashboard-admin
```

## Components Installed

- `kubernetes-dashboard` namespace
- Dashboard deployment and service
- Dashboard metrics scraper
- Metrics Server deployment
- Service accounts and RBAC roles
- Dashboard admin with cluster-admin access
