variable "cluster_name" {
  type = string
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "node_group_desired_count" {
  type    = number
  default = 2
}

variable "node_group_instance_type" {
  type    = string
  default = "t3.medium"
}
