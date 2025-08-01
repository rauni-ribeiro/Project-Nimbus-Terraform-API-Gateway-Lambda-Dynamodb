# main.tf

provider "aws" {
  region = "us-east-1"
}

resource "aws_dynamodb_table" "lambda_db_table" {
  name         = "lambda_db_table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "admin_credentials" {
  table_name = aws_dynamodb_table.lambda_db_table.name
  hash_key   = "id"

  item = jsonencode({
    id       = { S = var.username_app }
    password = { S = var.password_app }
  })
}

#this is a placeholder messsage - just trying to get the code to work :)
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
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.lambda_db_table.arn
      }
    ]
  })
}

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

resource "aws_iam_role_policy_attachment" "policy-role-attachment" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
}

resource "aws_lambda_function" "API-app" {
  function_name = "API-app"
  role          = aws_iam_role.lambda_iam_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  filename      = "function.zip"
  source_code_hash = filebase64sha256("function.zip")
}

resource "aws_api_gateway_rest_api" "login_app_api" {
  name = "login-app-api"
  body = jsonencode({
    openapi = "3.0.1",
    info = {
      title   = "example",
      version = "1.0"
    },
    paths = {
      "/login" = {
        options = {
          x-amazon-apigateway-integration = {
            type = "mock",
            requestTemplates = {
              "application/json" = "{ \"statusCode\": 200 }"
            },
            responses = {
              default = {
                statusCode = "200",
                responseParameters = {
                  "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'",
                  "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'",
                  "method.response.header.Access-Control-Allow-Origin"  = "'*'"
                },
                responseTemplates = {
                  "application/json" = ""
                }
              }
            }
          },
          responses = {
            "200" = {
              description = "Default response for CORS method",
              headers = {
                "Access-Control-Allow-Headers" = {
                  schema = {
                    type = "string"
                  }
                },
                "Access-Control-Allow-Methods" = {
                  schema = {
                    type = "string"
                  }
                },
                "Access-Control-Allow-Origin" = {
                  schema = {
                    type = "string"
                  }
                }
              }
            }
          }
        },
        post = {
          x-amazon-apigateway-integration = {
            type                  = "AWS_PROXY",
            httpMethod            = "POST",
            uri                   = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.API-app.arn}/invocations",
            IntegrationHTTPMethod = "POST"
          }
        }
      }
    }
  })
}

resource "aws_api_gateway_deployment" "api-deployment" {
  depends_on = [aws_api_gateway_rest_api.login_app_api]
  rest_api_id = aws_api_gateway_rest_api.login_app_api.id
}

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
  source_arn    = "${aws_api_gateway_rest_api.login_app_api.execution_arn}/*/*"
}
