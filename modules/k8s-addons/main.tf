# EKS Addons - Kubernetes Dashboard and Metrics Server

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# Metrics Server - Required for Dashboard
resource "kubectl_manifest" "metrics_server" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      labels:
        k8s-app: metrics-server
      name: metrics-server
      namespace: kube-system
  YAML

  depends_on = [var.cluster_id]
}

resource "kubectl_manifest" "metrics_server_deployment" {
  yaml_body = <<-YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      labels:
        k8s-app: metrics-server
      name: metrics-server
      namespace: kube-system
    spec:
      selector:
        matchLabels:
          k8s-app: metrics-server
      strategy:
        rollingUpdate:
          maxUnavailable: 0
      template:
        metadata:
          labels:
            k8s-app: metrics-server
        spec:
          containers:
          - args:
            - --cert-dir=/tmp
            - --secure-port=4443
            - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
            - --kubelet-use-node-status-port
            - --metric-resolution=15s
            image: registry.k8s.io/metrics-server/metrics-server:v0.6.4
            imagePullPolicy: IfNotPresent
            livenessProbe:
              failureThreshold: 3
              httpGet:
                path: /livez
                port: https
                scheme: HTTPS
              periodSeconds: 10
            name: metrics-server
            ports:
            - containerPort: 4443
              name: https
              protocol: TCP
            readinessProbe:
              failureThreshold: 3
              httpGet:
                path: /readyz
                port: https
                scheme: HTTPS
              initialDelaySeconds: 20
              periodSeconds: 10
            resources:
              requests:
                cpu: 100m
                memory: 200Mi
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              runAsNonRoot: true
              runAsUser: 1000
            volumeMounts:
            - mountPath: /tmp
              name: tmp-dir
          nodeSelector:
            kubernetes.io/os: linux
          priorityClassName: system-cluster-critical
          serviceAccountName: metrics-server
          volumes:
          - emptyDir: {}
            name: tmp-dir
  YAML

  depends_on = [kubectl_manifest.metrics_server]
}

# Kubernetes Dashboard
resource "kubectl_manifest" "dashboard_namespace" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: Namespace
    metadata:
      name: kubernetes-dashboard
  YAML

  depends_on = [var.cluster_id]
}

resource "kubectl_manifest" "dashboard" {
  yaml_body = file("${path.module}/manifests/kubernetes-dashboard.yaml")

  depends_on = [kubectl_manifest.dashboard_namespace]
}

# Dashboard Admin User
resource "kubernetes_service_account" "dashboard_admin" {
  metadata {
    name      = "dashboard-admin"
    namespace = "kubernetes-dashboard"
  }

  depends_on = [kubectl_manifest.dashboard_namespace]
}

resource "kubernetes_cluster_role_binding" "dashboard_admin" {
  metadata {
    name = "dashboard-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.dashboard_admin.metadata[0].name
    namespace = kubernetes_service_account.dashboard_admin.metadata[0].namespace
  }
}

# Create token secret for dashboard admin
resource "kubernetes_secret" "dashboard_admin_token" {
  metadata {
    name      = "dashboard-admin-token"
    namespace = "kubernetes-dashboard"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.dashboard_admin.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"

  depends_on = [kubernetes_service_account.dashboard_admin]
}
