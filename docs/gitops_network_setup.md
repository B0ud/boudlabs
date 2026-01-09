# GitOps & Network Setup Documentation

## Overview
This document outlines the network architecture and GitOps configuration for the BoudLabs cluster.

## Components

### 1. FluxCD (GitOps)
Flux is installed to synchronize the cluster state with the `gitops/` directory.
- **Source**: `gitops/` directory in the repository.
- **Bootstrap**: Managed via Terraform `flux_bootstrap_git`.
- **Structure**:
    - `0_fluxcd`: Flux system components.
    - `1_apps-of-apps`: Application bundles.
    - `2_cert-manager`: Certificate management infrastructure.
    - `3_gateway_cillium`: Gateway API and Networking configurations.

### 2. Cilium (CNI & Service Mesh)
Cilium is installed via Helm (v1.18.5) and serves as the CNI and Gateway API implementation.
- **Namespace**: `kube-system`
- **Values**: Configured in `kubernetes/cilium/values.yaml`

### 3. Gateway API
Two distinct Gateways are configured to separate public and private traffic.

| Feature | Public Gateway | Private Gateway |
| :--- | :--- | :--- |
| **Name** | `gateway-public` | `gateway-privee` |
| **Purpose** | External Internet Traffic | Internal / WireGuard Traffic |
| **NodePort HTTP** | `30080` | `31080` |
| **NodePort HTTPS** | `30443` | `31443` |

### 4. Certificate Management
Certificates are managed by `cert-manager` with a self-signed ClusterIssuer as a fallback/default.
- **Issuer**: `selfsigned-issuer`
- **Public Cert**: `default-public-cert` (Secret)
- **Private Cert**: `default-private-cert` (Secret)

### 5. Services (NodePort)
Traffic enters the cluster via NodePorts exposed on all worker nodes. These NodePorts will be the backend targets for the HAProxy Load Balancer.
- **Service Name**: `cilium-gateway-public-nodeport` & `cilium-gateway-private-nodeport`
- **Traffic Flow**: HAProxy -> Worker Node (NodePort) -> Cilium Gateway -> Pod
- **Infrastructure Code**: `infrastructure/provisioning/modules/haproxy-vm`
