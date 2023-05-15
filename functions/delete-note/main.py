import boto3
import json

dynamodb_resource = boto3.resource("dynamodb")
table = dynamodb_resource.Table("lotion-30142625")

def lambda_handler(event, context):
    email = event["queryStringParameters"]["email"]
    id = event["queryStringParameters"]["id"]
    try:
        response = table.delete_item(
            Key={
                "email": email,
                "id": id
            }
        )
        status_code = response['ResponseMetadata']['HTTPStatusCode']
        print(status_code)
    except Exception as exp:
        print(f"exception: {exp}")
        return {
            "statusCode": 401,
                "body": json.dumps({
                    "message": str(exp)
            })
        }