variable "env" {
  type = string
  validation{
    condition = contains(["devel","stage","prod"],var.env)
    error_message = "env must be one of devel, stage, or prod"
  }
}

variable "account_suffix"{
  type = string
}

variable "tags" {
  type = map(string)
  default = {}  
}