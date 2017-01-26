from __future__ import print_function

import boto3 
import ConfigParser
import base64
import pymysql
import os
import io
import sys

print('Loading function')

s3 = boto3.client('s3')
kms = boto3.client('kms')


def lambda_handler(event, context):

    #Use this as a semaphore to ensure we have the informaiton
    #Log it to audit what lambda is reading in
    if 'Loaded' in os.environ:
        print (os.environ['Loaded'])
    else:
        get_config(section_name='mysql')

    try:
            conn = pymysql.connect(os.environ['host'], user=os.environ['user'], passwd=os.environ['passwd'], db=os.environ['db'], connect_timeout=5)
            if conn:
                print("mysql connected")
    except pymysql.InternalError as e:
            print('Got error {!r}, errno is {}'.format(e, e.args[0]))
            sys.exit()

    conn.close()

def get_config(section_name):
    #Bucket and Key are set in the Lmabda environment to facilitate
    # creating dev/test/production envirnments at run-time
    # or allow different versions of the Lambda
    if 'Bucket' in os.environ:
        bucket = os.environ['Bucket']
    else:
        print("Need 'Bucket' specified (S3 bucket that has configuration")
        sys.exit()

    if 'Key' in os.environ:
        key = os.environ['Key']
    else:
        print("Need 'Key' specified (S3 object that has configuration")
        sys.exit()

    print("in get_config")

    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        print("CONTENT TYPE: " + response['ContentType'])

    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e

    try:
        config_text = kms.decrypt(CiphertextBlob=response['Body'].read()).get('Plaintext')
        # Useful for debugging, a HUGE security hole in production!
        #print (config_text)

    except Exception as e:
        print(e)
        print('Error decrypting object {} from object {} '.format(base64.base64encode(CiphertextBlob=response['Body'].read()), bucket))
        raise e

    #Configure the parser, then read the configuration from the decrypted buffer
    config = ConfigParser.RawConfigParser(allow_no_value=True)
    config.readfp(io.BytesIO(config_text))
    for name,value in config.items(section_name):
        os.environ[name] = value
    os.environ['Loaded'] = bucket + "/" + key
    
    #For debugging/auditing
    print(os.environ['Loaded'])
