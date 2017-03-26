# Document Upload Portal - Infra

This is the Infrastructure as Code for a [sample Document Upload portal
application](github.com/so0k/aws-uploads-sample).

Tested on:
```
Terraform v0.7.13
aws-cli/1.11.24 Python/2.7.12 Darwin/15.6.0 botocore/1.5.3
```

## Getting Started

```bash
# prereqs
$ brew update && brew install awscli jq terraform

# Create and upload ssh key to AWS
$ make create-keypair

# Init infra directory locally
$ make init

# Plan Terraform provisioning
$ terraform plan

# Provision infrastructure
$ terraform apply
```

**NOTE**: On terraform 0.7 there is a known dependency issue with ECS roles due to the eventual consistency of IAM resulting in:
```
1 error(s) occurred:

* aws_ecs_service.uploads: InvalidParameterException: Unable to assume role and validate the specified targetGroupArn.
```

running `terraform apply` a second time should complete without issue

## Clean up

```bash
$ terraform destroy

# delete keypair locally and in AWS
$ make clean
```

## Why ECS?

EC2 Container Service provides a minimal way to create a cloud hosted cluster
to run Linux containers in a robust and reliable way.

Alternative options:

- Create a k8s cluster: This was personal preference, but disqualified due to large overhead for a simple application
- Use GKE: More familiar with AWS S3 for object storage
- Deploy on to instances directly using Ansible: Prefer to leverage the ease of deployment of containers.

## References:

- [Terraform ECS sample](https://github.com/hashicorp/terraform/tree/master/examples/aws-ecs-alb)
- [kz8s/tack](https://github.com/kz8s/tack)
