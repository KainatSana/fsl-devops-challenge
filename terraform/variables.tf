# In this file put the variables related to the deployment
variable "env" {
    type = string
    validation {
      condition = contains(["devel","stage","prod"],var.env)
      error_message = "env must be devel , stage or prod"
    }

}

variable "account_suffix" {
      type = string
}

variable "tags"{
 type = map(string)
 default = {}
}