## IAM

resource "aws_iam_role" "ecs_service" {
  name = "ecs_${var.cluster_name}_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_service" {
  name = "ecs_${var.cluster_name}_policy"
  role = "${aws_iam_role.ecs_service.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "app" {
  name  = "ecs-${var.cluster_name}-instprofile"
  roles = ["${aws_iam_role.app_instance.name}"]
}

resource "aws_iam_role" "app_instance" {
  name = "ecs-${var.cluster_name}-instance-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "template_file" "instance_profile" {
  template = "${file("${path.module}/templates/instance-profile-policy.json")}"

  vars {
    app_log_group_arn = "${aws_cloudwatch_log_group.app.arn}"
    ecs_log_group_arn = "${aws_cloudwatch_log_group.ecs.arn}"
  }
}

resource "aws_iam_role_policy" "instance" {
  name   = "Ecs${title(var.cluster_name)}InstanceRole"
  role   = "${aws_iam_role.app_instance.name}"
  policy = "${data.template_file.instance_profile.rendered}"
}

resource "aws_iam_user" "uploads_user" {
    name = "${var.uploads_bucket}-user"
    path = "/system/" #used in IAM Identity
}

resource "aws_iam_access_key" "uploads_user" {
    user = "${aws_iam_user.uploads_user.name}"
}

resource "aws_iam_user_policy" "uploads_user" {
    name = "${var.uploads_bucket}-uploads"
    user = "${aws_iam_user.uploads_user.name}"
    policy= <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject"
        ],
        "Resource": [
            "arn:aws:s3:::${var.uploads_bucket}/*"
        ]
     }]
}
EOF
}

resource "aws_iam_user" "backups_user" {
    name = "${var.uploads_bucket}-backups"
    path = "/system/" #used in IAM Identity
}

resource "aws_iam_access_key" "backups_user" {
    user = "${aws_iam_user.backups_user.name}"
}

resource "aws_iam_user_policy" "backups_user" {
    name = "${var.uploads_bucket}-sync"
    user = "${aws_iam_user.backups_user.name}"
    policy= <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Effect": "Allow",
        "Action": [
          "s3:ListBucket",
          "s3:GetObject*",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        "Resource": [
            "arn:aws:s3:::${var.uploads_bucket}",
            "arn:aws:s3:::${var.uploads_bucket}/*"
        ]
     }]
}
EOF
}
