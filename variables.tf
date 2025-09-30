variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "vpc_name" {
  type    = string
  default = "demo_vpc"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "private_subnets" {
  default = {
    "private_subnet_1" = 1
    "private_subnet_2" = 2
    "private_subnet_3" = 3
  }
}

variable "public_subnets" {
  default = {
    "public_subnet_1" = 1
    "public_subnet_2" = 2
    "public_subnet_3" = 3
  }
}

variable "environment" {
  type        = string
  description = "Infrastructure environment. eg. dev, prod, etc"
  default     = "test"
}


variable "instance_type" { default = "t3.nano" }
variable "ami" { default = "ami-03601e822a943105f" }
variable "vpc_id" { default = "vpc-01c48ae5d78b50401" }
variable "subnet_id_a" { default = "subnet-060790e0b0642eca0" }
variable "subnet_id_b" { default = "subnet-0c916e4290d9491ce" }