````markdown
# Terraform AWS Kubernetes Cluster Setup

This repository contains Terraform code to provision a self-managed Kubernetes cluster on AWS using EC2 Spot Instances. The infrastructure includes VPC, subnets, security groups, IAM roles, and EC2 worker nodes to run Kubernetes.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Deploying the Cluster](#deploying-the-cluster)
- [Accessing the Cluster](#accessing-the-cluster)
- [Tearing Down the Infrastructure](#tearing-down-the-infrastructure)
- [Notes](#notes)
- [Additional Resources](#additional-resources)

---

## Prerequisites

Before running Terraform, make sure you have the following tools installed and configured:

1. **AWS CLI**: [Install AWS CLI](https://aws.amazon.com/cli/) and configure it:

   ```bash
   aws configure
````

2. **Terraform**: [Install Terraform](https://www.terraform.io/downloads.html)

3. **kubectl**: [Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

4. **IAM Permissions**: Ensure your AWS IAM user has permissions to manage EC2, VPCs, IAM roles, and networking components.

---

## Deploying the Cluster

### 1. Clone the Repository

```bash
git clone https://github.com/tmor32/kube-infra.git
cd k8s-terraform-aws
```

### 2. Initialize Terraform

Initialize the Terraform working directory:

```bash
terraform init
```

### 3. Validate the Terraform Configuration

Ensure your configuration files are valid:

```bash
terraform validate
```

### 4. Apply the Terraform Configuration

Deploy the infrastructure:

```bash
terraform apply
```

Terraform will display a plan of actions. Type `yes` to approve and create the infrastructure.

---

## Accessing the Cluster

Once the infrastructure is created:

### 1. SSH into the Master Node

Replace `<ip>` and `<key.pem>` with your actual values:

```bash
ssh -i path/to/key.pem ec2-user@<master-node-public-ip>
```

### 2. Initialize Kubernetes with kubeadm

On the master node:

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

### 3. Set Up `kubectl` for the Current User

Still on the master node:

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 4. Join Worker Nodes

On each worker node, run the join command shown in the output of `kubeadm init`. It will look like:

```bash
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

### 5. Install Flannel Network Plugin

From the master node:

```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

### 6. Verify Cluster Status

```bash
kubectl get nodes
```

All nodes should show a `Ready` status.

---

## Tearing Down the Infrastructure

To destroy all resources and avoid costs:

```bash
terraform destroy
```

Terraform will show a plan of what will be destroyed. Type `yes` to confirm.

---

## Notes

* **Spot Instances**: This setup uses Spot Instances for cost efficiency. They can be reclaimed by AWS at any time.
* **Not Production Ready**: This is ideal for learning, experimentation, or test workloads.
* **Persistent Storage**: Volumes may need manual cleanup depending on how they're provisioned.

---

## Additional Resources

* [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
* [Kubernetes Installation Guide](https://kubernetes.io/docs/setup/)
* [Flannel Network Plugin](https://github.com/flannel-io/flannel)

```

---

### ✅ Instructions:
Save this as `README.md` in your project root. It will render properly on GitHub or any other Markdown renderer.

Let me know if you'd like to include instructions for automating `kubeadm` steps or using `kOps` or `eksctl` instead.
```
