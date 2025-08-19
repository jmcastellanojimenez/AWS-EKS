# EKS Foundation Platform

## Product Overview

The EKS Foundation Platform is a comprehensive Kubernetes infrastructure project designed to provide enterprise-grade container orchestration on AWS. The platform serves as a foundation for deploying and managing microservices applications, specifically designed to support the EcoTrack application ecosystem.

## Key Features

- **Multi-environment EKS clusters** with standardized configurations (dev, staging, prod)
- **Complete observability stack** using LGTM (Loki, Grafana, Tempo, Mimir) with Prometheus
- **Production-ready ingress** with Ambassador API Gateway, cert-manager, and external-dns
- **Infrastructure as Code** using Terraform with modular architecture
- **GitOps-ready** with manual deployment workflows via GitHub Actions
- **Cost-optimized** using spot instances and lifecycle policies

## Target Applications

The platform is specifically designed to support:
- **EcoTrack microservices** (5 planned services: user, product, order, payment, notification)
- **Spring Boot applications** with actuator endpoints and OpenTelemetry tracing
- **RESTful APIs** with comprehensive monitoring and logging
- **Database-backed services** with persistent storage requirements

## Architecture Philosophy

- **Security-first** with IRSA, KMS encryption, and proper IAM roles
- **Observability-native** with metrics, logs, and traces from day one
- **Scalable by design** with auto-scaling node groups and horizontal pod scaling
- **Cost-conscious** using spot instances and S3 lifecycle policies
- **Environment parity** with consistent configurations across dev/staging/prod