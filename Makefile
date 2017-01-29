#Separate CLI profiles for the security account
# and the account deploying the Lambda
SECURITY_PROFILE=default
LAMBDA_PROFILE=Matt-Lab-Dev
#Make sure this is correct for KMS and Lambda
#Keep them the same region for performance!
REGION=us-west-2

#The bucket the secretes are stored in
# Don't forget to set the Bucket policy
# to allow access to the Role the Lambda uses
BUCKET=ndh-secrets
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


#Flags
#Flag for updating environment variables
ENV_DELIVERED=env_delivered
#Flag for updating encrypted objects
ENC_DELIVERED=enc_delivered
#Flag for updating Lambda
LAMBDA_DELIVERED=lambda_delivered



$(ENC): $(CFG)
	aws kms encrypt --key-id arn:aws:kms:us-west-2:323826331358:key/7f6907a1-c040-4d47-9807-a28411333906 --plaintext fileb://$? --output text --query CiphertextBlob --profile $(SECURITY_PROFILE) --region $(REGION) | base64 --decode > $@

$(ENC_DELIVERED): $(ENC)
	aws s3 cp $(ENC) s3://$(BUCKET)/$(KEY)  --profile $(SECURITY_PROFILE) --region $(REGION) && touch $(ENC_DELIVERED)

$(ENV_DELIVERED): Makefile
	aws lambda update-function-configuration --function-name lambda-mysql --environment 'Variables={Bucket=$(BUCKET),Key=$(KEY)}'  --profile $(LAMBDA_PROFILE) --region $(REGION) && touch $(ENV_DELIVERED)

$(LIBS): 
	pip install $@ -t .

$(ZIPFILE) : $(SRC) $(LIBS)
	$(ZIP) $(ZIPOPTIONS) $(ZIPFILE) $(SRC) $(LIBS)

$(LAMBDA_DELIVERED): $(ZIPFILE)
	aws lambda update-function-code --function-name lambda-mysql --zip-file fileb://$(ZIPFILE) --profile $(LAMBDA_PROFILE) --region $(REGION) && touch $(LAMBDA_DELIVERED)

$(LAMBDA): $(ZIPFILE) 

all: $(LAMBDA) $(ENC_DELIVERED) $(LAMBDA_DELIVERED) $(ENV_DELIVERED)
