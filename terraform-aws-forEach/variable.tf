variable "env" {
  description = "for resourses names"
  type        = string
  default     = "dev"
}

variable "vpc_ciders" {
  description = "for vpc ciders"
  type        = string
  default     = "10.10.0.0/16"
}

variable "allowed_ports" {
  type    = list(number)
  default = [22, 80, 443]
}

variable "public_subnets_ciders" {
  description = "ciders for public subnets"
  type        = map(string)
  default = {
    pub-1 = "10.10.1.0/24"
    pub-2 = "10.10.2.0/24"
  }
}

variable "private_subnets_ciders" {
  description = "ciders for private subnets"
  type        = map(string)
  default = {
    priv-1 = "10.10.3.0/24"
    priv-2 = "10.10.4.0/24"
    priv-3 = "10.10.5.0/24"
  }
}
