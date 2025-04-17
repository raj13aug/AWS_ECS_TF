resource "aws_ecs_cluster" "ECS" {
  name = "my-demo-cluster"

  tags = {
    Name = "my-demo-cluster"
  }
}   