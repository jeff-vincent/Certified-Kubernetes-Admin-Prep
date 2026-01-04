 # Certified Kubernetes Administrator (CKA) Practice Labs

## Overview

I’m already familiar with Kubernetes from years of hands-on experience across multiple environments, but I only recently set out to formally earn the **Certified Kubernetes Administrator (CKA)** credential.

While preparing, I noticed that many high-quality practice resources are **paid, fragmented, or overly simplified**. Since Kubernetes itself gives us everything we need to build realistic failure scenarios, I decided to create my own **hands-on, break/fix–style practice labs** that mirror the kinds of problems you actually encounter on the CKA exam (and in real clusters).

This repository is intended to:

- Eliminate the legwork of inventing realistic practice scenarios
- Encourage *diagnosis-first* troubleshooting instead of rote command memorization
- Provide repeatable, script-driven failure and validation workflows
- Stay close to **upstream Kubernetes behavior** (no vendor abstractions)

> **NOTE:** This resource is actively under construction. Scenarios may evolve as I continue refining difficulty, realism, and exam coverage.

---

## Philosophy & Intended Skill Level

These scenarios assume you:

- Are comfortable with `kubectl`
- Understand core Kubernetes concepts (nodes, pods, services, volumes)
- Want to practice **system-level troubleshooting**, not YAML memorization

If you’re brand new to Kubernetes, this is probably *not* the right starting point.

---

## Getting Started

All practice scenarios assume a **bare-metal-style Kubernetes cluster** running on Ubuntu 24.04.

I use **DigitalOcean Droplets**, but any environment where you have:

- Root access to nodes
- systemd-managed kubelet
- A kubeadm-initialized cluster

will work.

### Cluster Setup

Follow the instructions in my accompanying blog post:

**[Bare Metal Kubernetes on Ubuntu 24.04](https://medium.com/@jeff.d.vincent/bare-metal-k8s-cluster-for-dummies-fc3616b2debb)**

Once your cluster is up and healthy:

```bash
kubectl get nodes
kubectl get pods -A
```

# Practice Scenarios

## Practice Scenario 1 — Node, Networking, RBAC, Storage, Control Plane

**Focus:** Core cluster recovery & dependency ordering

### Topics Covered
- kubelet failures and node readiness
- CNI configuration vs CNI plugin binaries
- Pod sandbox creation failures
- Static pod misconfiguration (kube-apiserver)
- RBAC scope and verb mismatches
- CrashLoopBackOff vs liveness probe misconfiguration
- PersistentVolume / PersistentVolumeClaim mismatches

### Skills Practiced
- Reading node and pod events
- Diagnosing failures that cascade across layers
- Understanding which components must be fixed first
- Using validation commands under exam-style pressure

---

## Practice Scenario 2 — Networking, DNS, RBAC Scope, Images, StorageClasses

**Focus:** Cluster services & workload correctness

### Topics Covered
- kube-dns / CoreDNS failures
- DNS resolution inside pods
- Namespace-scoped RBAC errors
- ImagePullBackOff diagnostics
- StorageClass selection and binding logic
- PVCs stuck in `Pending` due to subtle mismatches

### Skills Practiced
- Debugging inside running pods
- Distinguishing control-plane health from workload health
- Interpreting scheduler and controller-manager behavior

---

## Practice Scenario 3 — Control Plane & Certificate Failures

**Focus:** Control plane stability and security primitives

### Topics Covered
- kube-apiserver instability
- Invalid or expired certificates
- etcd connectivity misconfiguration
- kubeconfig context errors
- Component health endpoints

### Skills Practiced
- Static pod inspection and recovery
- Reading control-plane logs
- Understanding certificate trust chains
- Restoring API availability without reinitializing the cluster

---

## Practice Scenario 4 — Scheduling, Resources, and Node Constraints

**Focus:** Why pods don’t schedule

### Topics Covered
- Node taints and tolerations
- Impossible resource requests
- Unsatisfiable affinity / anti-affinity rules
- Pod priority and preemption
- Scheduler diagnostics

### Skills Practiced
- Reading scheduler events
- Understanding why pods remain in `Pending`
- Differentiating scheduling failures from runtime failures

---

## Practice Scenario 5 — Stateful Workloads, Networking Policies, Storage

**Focus:** StatefulSets and isolation

### Topics Covered
- StatefulSet rollout failures
- Headless services
- PersistentVolume reuse constraints
- StorageClass reclaim policies
- NetworkPolicy blocking pod-to-pod traffic

### Skills Practiced
- Stateful workload troubleshooting
- Storage lifecycle awareness
- NetworkPolicy reasoning (ingress vs egress)
- Debugging “everything is running but nothing works” scenarios

---

## How to Use a Scenario

For any given scenario directory:

### 1. Break the cluster
```bash
./break-cluster.sh
```

### 2. Return the cluster and deployed resources to a healthy state

 Work through the accompanying task list to get everything healthy and running again.

- No step-by-step instructions are provided

- Use kubectl, logs, events, and direct node access

- Fix issues in the correct dependency order

### 3. Validate Success
```bash
./validate-cluster.sh
```

## Exam Alignment

These scenarios map closely to the official CKA curriculum, including:

- Cluster Architecture, Installation & Configuration

- Workloads & Scheduling

- Services & Networking

- Storage

- Troubleshooting

They are intentionally designed to feel like real production incidents, not sanitized exam questions.

## Final Note

If this repository saves you time, stress, or money while prepping for the CKA — mission accomplished.

Happy K8s-ing!!! 
