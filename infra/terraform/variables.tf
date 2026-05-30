variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "cloudopshub-cluster"
}

variable "node_group_desired_count" {
  type    = number
  default = 2
}

variable "node_group_instance_type" {
  type    = string
  default = "t3.medium"
}
