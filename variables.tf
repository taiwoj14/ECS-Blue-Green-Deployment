variable "application_name" {
    type = string
    default = "ecs-app"

}

variable "family" {
  description = "The family name of the task definition"
  type        = string
  default     = "app-task"
}

variable "container_name" {
  description = "The name of the container"
  type        = string
  default     = "app"
}

variable "image" {
  description = "The image URI"
  type        = string
  default     = "ooghenekaro/barbers-app-postgres"
}

variable "memory" {
  description = "The amount of memory to allocate to the container"
  type        = string
  default     = "512" # In MiB
}

variable "cpu" {
  description = "The amount of CPU to allocate to the container"
  type        = string
  default     = "256" # CPU units
}

variable "role_arn" {
  description = "The ARN of the IAM role"
  type        = string
  default     = "arn:aws:iam:481195358488::role/ecsTaskExecutionRole"
}

variable "deployment_group" {
  description = "The name of the CodeDeploy deployment group"
  type        = string
  default     = "ecs-dg"
}

variable "service_name" {
  description = "The name of the ECS service"
  type        = string
  default     = "app-service"
}
