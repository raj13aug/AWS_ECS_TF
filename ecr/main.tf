resource "aws_ecr_repository" "my_repo" {
  name = "ecs-app-repo"
}

resource "null_resource" "docker_clone_push" {
  # Only runs after repo is created
  depends_on = [aws_ecr_repository.my_repo]

  provisioner "local-exec" {
    command = <<EOT
      # Define vars
      AWS_REGION=us-east-1
      IMAGE_NAME=gomurali/exp-app-1:2
      ECR_URI=${aws_ecr_repository.my_repo.repository_url}

      # Login to ECR
      aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URI

      # Pull from Docker Hub
      docker pull $IMAGE_NAME:latest

      # Tag for ECR
      docker tag $IMAGE_NAME:latest $ECR_URI:latest

      # Push to ECR
      docker push $ECR_URI:latest
    EOT
  }
}
