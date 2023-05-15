terraform {
  required_providers {
    aws = {
      version = ">= 4.0.0"
      source  = "hashicorp/aws"
    }
  }
}

# specify the provider region
provider "aws" {
  region = "ca-central-1"
}

// SAVE NOTE

# create a role for the Lambda function to assume
# every service on AWS that wants to call other AWS services should first assume a role and
# then any policy attached to the role will give permissions
# to the service so it can interact with other AWS services
# see the docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "lambda" {
  name               = "iam-for-lambda-save-note-30141172"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# create archive file from main.py
data "archive_file" "save-note-archive" {
  type = "zip"
  # this file (main.py) needs to exist in the same folder as this 
  # Terraform configuration file
  source_file = "../functions/save-note/main.py"
  output_path = "artifact.zip"
}

# create a Lambda function
# see the docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function
resource "aws_lambda_function" "lambda" {
  role             = aws_iam_role.lambda.arn
  function_name    = "save-note-30141172"
  handler          = "main.lambda_handler"
  filename         = "artifact.zip"
  source_code_hash = data.archive_file.save-note-archive.output_base64sha256

  # see all available runtimes here: https://docs.aws.amazon.com/lambda/latest/dg/API_CreateFunction.html#SSS-CreateFunction-request-Runtime
  runtime = "python3.9"
}

# create a policy for publishing logs to CloudWatch
# see the docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "logs" {
  name        = "lambda-logging-save-note-30141172"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "dynamodb:*"
      ],
      "Resource": ["arn:aws:logs:*:*:*","${aws_dynamodb_table.lotion-30142625.arn}"],
      "Effect": "Allow"
    }
  ]
}
EOF
}

# attach the above policy to the function role
# see the docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.logs.arn
}

# create a Function URL for Lambda 
# see the docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_url
resource "aws_lambda_function_url" "url" {
  function_name      = aws_lambda_function.lambda.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["POST"]
    allow_headers     = ["*"]
    expose_headers    = ["keep-alive", "date"]
  }
}

# show the Function URL after creation
output "lambda_url" {
  value = aws_lambda_function_url.url.function_url
}

# read the docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table
resource "aws_dynamodb_table" "lotion-30142625" {
  name         = "lotion-30142625"
  billing_mode = "PROVISIONED"

  # up to 8KB read per second (eventually consistent)
  read_capacity = 1

  # up to 1KB per second
  write_capacity = 1

  # we only need a student id to find an item in the table; therefore, we 
  # don't need a sort key here
  hash_key = "email"
  range_key = "id"

  # the hash_key data type is string
  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "id"
    type = "S"
  }
}

/***************************************************************************************************/
// DELETE NOTE
# create a role for the Lambda function to assume
resource "aws_iam_role" "lambda_delete_note" {
  name               = "iam-for-lambda-delete-note"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# create archive file from delete_note.py
data "archive_file" "delete-note-30141172-archive" {
  type = "zip"
  source_file = "../functions/delete-note/main.py"
  output_path = "delete_note.zip"
}

# create a Lambda function for deleting a note
resource "aws_lambda_function" "lambda_delete_note" {
  role             = aws_iam_role.lambda_delete_note.arn
  function_name    = "delete-note-30141172"
  handler          = "main.lambda_handler"
  filename         = "delete_note.zip"
  source_code_hash = data.archive_file.delete-note-30141172-archive.output_base64sha256
  runtime          = "python3.9"
}

# create a policy for deleting notes from the DynamoDB table
resource "aws_iam_policy" "dynamodb_delete_policy" {
  name = "dynamodb-delete-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "dynamodb:DeleteItem"
        Effect = "Allow"
        Resource = aws_dynamodb_table.lotion-30142625.arn
      },
      {
        Action = ["logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

# attach the above policy to the function role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_delete_policy" {
  policy_arn = aws_iam_policy.dynamodb_delete_policy.arn
  role       = aws_iam_role.lambda_delete_note.name
}

# create a Function URL for Lambda 
resource "aws_lambda_function_url" "delete_note_url" {
  function_name      = aws_lambda_function.lambda_delete_note.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["DELETE"]
    allow_headers     = ["*"]
    expose_headers    = ["keep-alive", "date"]
  }
}

# show the Function URL after creation
output "delete_note_url" {
  value = aws_lambda_function_url.delete_note_url.function_url
}

/***************************************************************************************************/
// GET NOTES
# create a role for the Lambda function to assume
resource "aws_iam_role" "lambda_get_notes" {
  name               = "iam-for-lambda-get-notes"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# create archive file from delete_note.py
data "archive_file" "get-notes-30141172-archive" {
  type = "zip"
  source_file = "../functions/get-notes/main.py"
  output_path = "get_notes.zip"
}

# create a Lambda function for deleting a note
resource "aws_lambda_function" "lambda_get_notes" {
  role             = aws_iam_role.lambda_get_notes.arn
  function_name    = "get-notes-30141172"
  handler          = "main.lambda_handler"
  filename         = "get_notes.zip"
  source_code_hash = data.archive_file.get-notes-30141172-archive.output_base64sha256
  runtime          = "python3.9"
}

# create a policy for deleting notes from the DynamoDB table
resource "aws_iam_policy" "dynamodb_get_policy" {
  name = "dynamodb-get-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "dynamodb:Query"
        Effect = "Allow"
        Resource = aws_dynamodb_table.lotion-30142625.arn
      },
      {
        Action = ["logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

# attach the above policy to the function role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_get_policy" {
  policy_arn = aws_iam_policy.dynamodb_get_policy.arn
  role       = aws_iam_role.lambda_get_notes.name
}

# create a Function URL for Lambda 
resource "aws_lambda_function_url" "get_notes_url" {
  function_name      = aws_lambda_function.lambda_get_notes.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["GET"]
    allow_headers     = ["*"]
    expose_headers    = ["keep-alive", "date"]
  }
}

# show the Function URL after creation
output "get_notes_url" {
  value = aws_lambda_function_url.get_notes_url.function_url
}