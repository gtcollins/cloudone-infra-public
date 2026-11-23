variable "name" {
  description = "Prefix for resource names, e.g. cloudone-dev"
  type        = string
}

variable "deletion_window_in_days" {
  description = "Days a deleted key can still be recovered (7-30)"
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}
