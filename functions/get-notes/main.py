# add your get-notes function here
import boto3
from boto3.dynamodb.conditions import Key
import json

dynamodb_resource = boto3.resource("dynamodb")
table = dynamodb_resource.Table("lotion-30142625")

def lambda_handler(event, context):
    email = event["queryStringParameters"]["email"]
    try:
        response = table.query(
            KeyConditionExpression=Key("email").eq(email)
        )
        items = response["Items"]
        if (len(items) != 0):
            return items
        else:
            return []
        
    except Exception as exp:
        print(f"exception: {exp}")
        return {
            "statusCode": 401,
                "body": json.dumps({
                    "message": str(exp)
            })
        }