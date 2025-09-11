variable "name" {
  type        = string
  description = "The name of the resource"
  default     = "example"
}

locals {
  id = var.name
}
