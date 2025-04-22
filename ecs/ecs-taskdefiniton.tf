
# Featch the ECR Repo
data "aws_ecr_repository" "existing_repo" {
  name = "ecs-app-repo"
}

# Local variable for fallback value
locals {
  ecr_repository_url = try("gomurali/exp-app-1:2", "${data.aws_ecr_repository.existing_repo.repository_url}:latest")
}

#Defined a task for ECS 
resource "aws_ecs_task_definition" "TD" {
  family                   = "nginx"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.iam-role.arn
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  container_definitions = jsonencode([
    {
      name      = "container"
      image     = local.ecr_repository_url #"${data.aws_ecr_repository.existing_repo.repository_url}:latest" 
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

# use for outside of terraform config
data "aws_ecs_task_definition" "TD" {
  task_definition = aws_ecs_task_definition.TD.family
}