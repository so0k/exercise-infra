# Document Upload Portal - Infra

This is the Infrastructure as Code for a sample Document Upload portal
application.






















```bash
export AWS_DEFAULT_PROFILE=personal
```

```bash
# prereqs
$ brew update && brew install awscli cfssl jq terraform

# build artifacts and deploy infra
$ make init
```







### Why ECS?

EC2 Container Service provides a minimal way to create a cloud hosted cluster
for Linux containers.

Alternative options:

- Create a k8s cluster: This was personal preference, but disqualified due to large overhead for a simple application
- Use GKE: More familiar with AWS S3 for object storage
- Deploy on to instances directly using Ansible: Prefer to leverage the ease of deployment of containers.

### References:

- [Terraform ECS sample](https://github.com/hashicorp/terraform/tree/master/examples/aws-ecs-alb)
- [kz8s/tack](https://github.com/kz8s/tack)







# ECS with ALB example

This example shows how to launch an ECS service frontend with Application Load Balancer.

The example uses latest CoreOS Stable AMIs.

To run, configure your AWS provider as described in https://www.terraform.io/docs/providers/aws/index.html

## Get up and running

Planning phase

```
terraform plan \
	-var admin_cidr_ingress='"{your_ip_address}/32"' \
	-var key_name={your_key_name}
```

Apply phase

```
terraform apply \
	-var admin_cidr_ingress='"{your_ip_address}/32"' \
	-var key_name={your_key_name}
```

Once the stack is created, wait for a few minutes and test the stack by launching a browser with the ALB url.

## Destroy :boom:

```
terraform destroy
```
