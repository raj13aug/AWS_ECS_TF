
#Attaches a policy to the ECS execution role
resource "aws_iam_role" "iam-role" {
  name               = "ECS-execution-role"
  assume_role_policy = file("${path.module}/iam-role.json")
}
