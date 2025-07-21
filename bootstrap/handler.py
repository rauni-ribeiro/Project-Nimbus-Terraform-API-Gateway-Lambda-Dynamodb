import json
import boto3
import os

dynamodb = boto3.client('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'lambda_db_table')

def lambda_handler(event, context):
    # Responder requisições de pré-vôo (CORS)
    if event['httpMethod'] == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            'body': json.dumps('CORS preflight response')
        }

    # Requisição POST para login
    if event['httpMethod'] == 'POST':
        try:
            body = json.loads(event['body'])
            username = body.get('username')
            password = body.get('password')

            if not username or not password:
                return {
                    'statusCode': 400,
                    'headers': {
                        'Access-Control-Allow-Origin': '*'
                    },
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
                    'headers': {
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({'message': 'Invalid credentials'})
                }

            stored_password = item.get('password', {}).get('S')
            if stored_password == password:
                return {
                    'statusCode': 200,
                    'headers': {
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({'message': 'Login successful'})
                }
            else:
                return {
                    'statusCode': 401,
                    'headers': {
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({'message': 'Invalid credentials'})
                }

        except Exception as e:
            return {
                'statusCode': 500,
                'headers': {
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'message': f'Error: {str(e)}'})
            }

    # Método não suportado
    return {
        'statusCode': 405,
        'headers': {
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({'message': 'Method not allowed'})
    }
