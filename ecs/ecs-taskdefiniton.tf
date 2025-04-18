# module "codepipeline" {
#   source = "../codepipeline"
# }

data "aws_ecr_repository" "existing_repo" {
  name = "ecs-app-repo"
}

locals {
  ecr_repository_url = try("${data.aws_ecr_repository.existing_repo.repository_url}:latest", "gomurali/exp-app-1:2")
}

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
      image     = local.ecr_repository_url #"${data.aws_ecr_repository.existing_repo.repository_url}:latest" #"gomurali/exp-app-1:2"
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


data "aws_ecs_task_definition" "TD" {
  task_definition = aws_ecs_task_definition.TD.family
}