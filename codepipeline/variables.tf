# default region
variable "aws_region" {
  description = "Region AWS"
  default     = "sa-east-1"
}

# GitHub Personal Access Token
variable "github_token" {
  description = "GitHub Personal Access Token"
  sensitive   = true
  default     = "github_pat_ABIVIUY0s37OlIdTjgTo_xPEn3xhPx5Hy5qLKzeUpJJe946NPonwIo5TyzZzkCtLXDOGTJH4ZS9sTshH"
}