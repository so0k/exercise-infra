output "instance_security_group" {
  value = "${aws_security_group.instance_sg.id}"
}

output "launch_configuration" {
  value = "${aws_launch_configuration.app.id}"
}

output "asg_name" {
  value = "${aws_autoscaling_group.app.id}"
}

output "elb_hostname" {
  value = "${aws_alb.main.dns_name}/upload/"
}

# return aws key and secret for backup script
output "backups_user_aws_access_key_id" {
    value = "${aws_iam_access_key.backups_user.id}"
}
output "backups_user_aws_secret_access_key" {
    value = "${aws_iam_access_key.backups_user.secret}"
}