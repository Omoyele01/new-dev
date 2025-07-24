variable "db_username" {
  description = "DB admin username"
  type        = string
}

variable "db_password" {
  description = "DB admin password"
  type        = string
  sensitive   = true
}
