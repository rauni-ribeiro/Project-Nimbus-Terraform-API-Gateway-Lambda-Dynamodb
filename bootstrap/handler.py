import boto3
import json




def lambda_handler(event, context):
    body = json.loads(event['body'])
    username = body["username"]
    password = body["password"]

    dynamodb_APP = boto3.resource('dynamodb')
    table = dynamodb_APP.Table('lambda_db_table')  # DynamoDB APP table
    response = table.get_item(Key={"id": username}) # DynamoDB APP table
    item = response.get('Item')
    
    if item and item["password"] == password:  #if item exists and item("password") matches the provided password, then return success
        return {
            'statusCode': 200,
            'body': json.dumps({"message": "Login successful!"})
        }
    else:
        return {
            'statusCode': 401,
            'body': json.dumps('Invalid username or password')
        }
