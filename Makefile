SHELL += -eu

AWS_REGION ?= ap-southeast-1
S3_CDN_BUCKET ?= so0k-cdn
S3_UPLOADS_BUCKET ?= so0k-uploads
CLUSTER_NAME ?= production

AWS_EC2_KEY_NAME ?= ecs-$(CLUSTER_NAME)
DIR_KEY_PAIR := .keypair

init: create-keypair terraform.tfvars

clean: delete-keypair
	rm terraform.tfvars

$(DIR_KEY_PAIR)/: ; mkdir -p $@

$(DIR_KEY_PAIR)/$(AWS_EC2_KEY_NAME).pem: | $(DIR_KEY_PAIR)/
	aws --region ${AWS_REGION} ec2 create-key-pair \
		--key-name ${AWS_EC2_KEY_NAME} \
		--query 'KeyMaterial' \
		--output text \
	> $@
	chmod 400 $@
	ssh-add $@
	echo "key_name = \"${AWS_EC2_KEY_NAME}\""

## create ec2 key-pair and add to authentication agent
create-keypair: $(DIR_KEY_PAIR)/$(AWS_EC2_KEY_NAME).pem

## delete ec2 key-pair and remove from authentication agent
delete-keypair:
	aws --region ${AWS_REGION} ec2 delete-key-pair --key-name ${AWS_EC2_KEY_NAME} || true
	ssh-add -L | grep "${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem" > ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pub
	if [ -a ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pub ]; then \
		ssh-add -d ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pub; \
	fi;
	@-rm -rf $(DIR_KEY_PAIR)/

terraform.tfvars:
	echo "## Generated using Makefile"
	echo "aws_region = \"${AWS_REGION}\"" >$@
	echo "cluster_name = \"${CLUSTER_NAME}\"" >>$@
	echo "cdn_bucket = \"${S3_CDN_BUCKET}\"" >>$@
	echo "uploads_bucket = \"${S3_UPLOADS_BUCKET}\"" >>$@
	echo "key_name = \"${AWS_EC2_KEY_NAME}\"" >>$@
	aws iam get-user --output text --query='User.Arn' | grep -Eo '[[:digit:]]{12}' \
	 | xargs -I {} echo "aws_account_id = \"{}\"" >>$@
	IP=`curl --silent ifconfig.co` && echo "admin_cidr_ingress = \"$${IP}/32\"" >>$@

.PHONY: create-key-pair delete-key-pair init clean
