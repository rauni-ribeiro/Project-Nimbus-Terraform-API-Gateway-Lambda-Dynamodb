#defining the DynamoDB table that will be used by the Lambda function
resource "aws_dynamodb_table" "lambda_db_table" {
  name         = "lambda_db_table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }


}

#creating a DynamoDB table item to be used by the Lambda function (name)
resource "aws_dynamodb_table_item" "admin_credentials" {
  table_name = aws_dynamodb_table.lambda_db_table.name
  hash_key   = "id"

  item = jsonencode({
    id       = { S = var.username_app }
    password = { S = var.password_app }
  })
}



#defining the policy for the Lambda function
resource "aws_iam_policy" "lambda_iam_policy" {
  name        = "lambda_exec_policy"
  description = "IAM policy for Lambda execution role"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem", #this one is optional
          "dynamodb:DeleteItem", #this one is optional
          "dynamodb:Scan",       #this one is optional
          "dynamodb:Query",      #this one is optional
          "logs:CreateLogGroup", #this one is optional
        ],
        Effect   = "Allow",
        Resource = "${aws_dynamodb_table.lambda_db_table.arn}" #specify which DynamoDB table you want to allow access to
        #(this is considered a good practice)
      }
    ]
  })
}


#creating an IAM role for the Lambda function
resource "aws_iam_role" "lambda_iam_role" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

#assigning the lambda policy to the IAM role
resource "aws_iam_role_policy_attachment" "policy-role-attachment" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
}

#creating the lambda function that will be invoked in the API Gateway
resource "aws_lambda_function" "API-app" {
  function_name = "API-app"
  role          = aws_iam_role.lambda_iam_role.arn #parsing the role from the IAM role created above
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"

  filename = "function.zip" #the zip file containing the lambda function code

  source_code_hash = filebase64sha256("function.zip") #hash of the zip file to ensure the code is up to date

}

#Creating the Login app REST API
resource "aws_api_gateway_rest_api" "login_app_api" {
  name = "login-app-api"
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "example"
      version = "1.0"
    }
    paths = {
      "/login" = {
        post = {
          x-amazon-apigateway-integration = {
            type                  = "AWS_PROXY"
            httpMethod            = "POST"
            uri                   = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.API-app.arn}/invocations"
            IntegrationHTTPMethod = "POST"
          }
        }
      }
    }
  })
}
#
resource "aws_api_gateway_deployment" "api-deployment" {
  depends_on = [aws_api_gateway_rest_api.login_app_api]

  rest_api_id = aws_api_gateway_rest_api.login_app_api.id
}

#creating a stage for the API Gateway
resource "aws_api_gateway_stage" "dev-stage" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.login_app_api.id
  deployment_id = aws_api_gateway_deployment.api-deployment.id
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.API-app.function_name
  principal     = "apigateway.amazonaws.com"

  # The source ARN is the ARN of the API Gateway stage
  source_arn = "${aws_api_gateway_rest_api.login_app_api.execution_arn}/*/*"
}