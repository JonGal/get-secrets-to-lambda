#Separate CLI profiles for the security account
# and the account deploying the Lambda
SECURITY_PROFILE=NDH_Security
LAMBDA_PROFILE=Matt-Lab-Dev
#Make sure this is correct for KMS and Lambda
#Keep them the same region for performance!
REGION=us-west-2

#The bucket the secretes are stored in
# Don't forget to set the Bucket policy
# to allow access to the Role the Lambda uses
BUCKET=ndh-secrets-bucket
#The Object the secrets are stored in
KEY=lambda/$(ENC)

#Deliverable
SRC=lambda-mysql.py
LIBS=pymysql
ZIP=zip
ZIPOPTIONS=-r
ZIPFILE=lambda-mysql.zip
LAMBDA=lambda-mysql
CFG=mysql_access.cfg
ENC=mysql_access.cfg.enc
KEY_ID=arn:aws:kms:us-west-2:072198522266:key/c216d1f7-025f-4c58-9f2c-86822aadf20d


#Flags
#Flag for updating environment variables
ENV_DELIVERED=env_delivered
#Flag for updating encrypted objects
ENC_DELIVERED=enc_delivered
#Flag for updating Lambda
LAMBDA_DELIVERED=lambda_delivered



$(ENC): $(CFG)
	aws kms encrypt --key-id $(KEY_ID) --plaintext fileb://$? --output text --query CiphertextBlob --profile $(SECURITY_PROFILE) --region $(REGION) | base64 --decode > $@ || rm $(ENC)

$(ENC_DELIVERED): $(ENC)
	aws s3 cp $(ENC) s3://$(BUCKET)/$(KEY)  --profile $(SECURITY_PROFILE) --region $(REGION) && touch $(ENC_DELIVERED)

$(ENV_DELIVERED): Makefile
	aws lambda update-function-configuration --function-name lambda-mysql --environment 'Variables={Bucket=$(BUCKET),Key=$(KEY)}'  --profile $(LAMBDA_PROFILE) --region $(REGION) && touch $(ENV_DELIVERED)

$(LIBS): 
	pip install $@ -t .

$(ZIPFILE) : $(SRC) $(LIBS)
	$(ZIP) $(ZIPFILE) $(ZIPOPTIONS) $(SRC) $(LIBS)

$(LAMBDA_DELIVERED): $(ZIPFILE)
	aws lambda update-function-code --function-name lambda-mysql --zip-file fileb://$(ZIPFILE) --profile $(LAMBDA_PROFILE) --region $(REGION) && touch $(LAMBDA_DELIVERED)

$(LAMBDA): $(ZIPFILE) 

all: $(LAMBDA) $(ENC_DELIVERED) $(LAMBDA_DELIVERED) $(ENV_DELIVERED)
