import json
import boto3
import os

dynamodb = boto3.client('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'lambda_db_table')

CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST,OPTIONS'
}

def lambda_handler(event, context):
    # Answer preflight requests for CORS
    if event['httpMethod'] == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': CORS_HEADERS,
            'body': json.dumps('CORS preflight response')
        }

    # Post request for login
    if event['httpMethod'] == 'POST':
        try:
            body = json.loads(event['body'])
            username = body.get('username')
            password = body.get('password')

            if not username or not password:
                return {
                    'statusCode': 400,
                    'headers': CORS_HEADERS,
                    'body': json.dumps({'message': 'Missing username or password'})
                }

            response = dynamodb.get_item(
                TableName=table_name,
                Key={'id': {'S': username}}
            )

            item = response.get('Item')
            if not item:
                return {
                    'statusCode': 401,
                    'headers': CORS_HEADERS,
                    'body': json.dumps({'message': 'Invalid credentials'})
                }

            stored_password = item.get('password', {}).get('S')
            if stored_password == password:
                return {
                    'statusCode': 200,
                    'headers': CORS_HEADERS,
                    'body': json.dumps({'message': 'Login successful'})
                }
            else:
                return {
                    'statusCode': 401,
                    'headers': CORS_HEADERS,
                    'body': json.dumps({'message': 'Invalid credentials'})
                }

        except Exception as e:
            return {
                'statusCode': 500,
                    'headers': CORS_HEADERS,
                'body': json.dumps({'message': f'Error: {str(e)}'})
            }

    # non supported HTTP methods
    return {
        'statusCode': 405,
        'headers': CORS_HEADERS,
        'body': json.dumps({'message': 'Method not allowed'})
    }
