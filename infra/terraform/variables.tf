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

variable "node_group_min_count" {
  type    = number
  default = 1
}

variable "node_group_max_count" {
  type    = number
  default = 3
}

variable "node_group_instance_type" {
  type    = string
  default = "t3.medium"
}
variable "db_password" {
  type      = string
  sensitive = true
}
