#!/bin/bash
# Function to display usage
usage() {
  echo "Usage: $0 --project-id=PROJECT_ID [--deploy=true] [--region=REGION]"
  exit 1
}
# Parse arguments
DEPLOY=false
REGION=""
IMAGE_NAME=""
REPO_NAME=""
PROJECT_ID=""
service_name="jwks-url-service"
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --deploy=*) DEPLOY="${1#*=}";;
    --region=*) REGION="${1#*=}";;
    --project-id=*) PROJECT_ID="${1#*=}";;
    *) usage;;
  esac
  shift
done
# Check if deploy is true and required variables are provided
if [[ "$DEPLOY" == "true" ]]; then
  if [[ -z "$REGION" || -z "$PROJECT_ID" ]]; then
    usage
  fi
else
  if [[ -z "$PROJECT_ID" ]]; then
    usage
  fi
fi

# main execution starts here

# Setting the project id for gcloud
gcloud config set project "$PROJECT_ID"

# Generate the key pair
ssh-keygen -t rsa -b 2048 -m PEM -f jwkscd_key -N ""
# Get the current timestamp in the desired format
TIMESTAMP=$(date +"%m-%d-%Y-%H-%M-%S")
# Step 2: Save the private and public key material in Google Cloud Secrets Manager
# Ensure you have the gcloud CLI installed and authenticated
echo "Creating a secret jwkscd_private_key_$TIMESTAMP"
# Save the private key with timestamp
gcloud secrets create jwkscd_private_key_$TIMESTAMP --data-file=jwkscd_key
echo "Creating a secret jwkscd_public_key_$TIMESTAMP"
# Save the public key with timestamp but in RSA PEM format that way we can use it for testing on JWD debugger
openssl rsa -in jwkscd_key -pubout -outform PEM -out jwkscd_key_rsa_pem.pub
gcloud secrets create jwkscd_public_key_$TIMESTAMP --data-file=jwkscd_key_rsa_pem.pub
# using - https://security.stackexchange.com/questions/218146/how-do-i-get-the-n-modulus-field-in-the-jwk-response
# and validated using - https://jwkset.com/generate
echo "Creating n and Key Id"
# Step 3: Use the public key to create a JWKS json file and generate the Key ID (KID)
# Step 1: Remove the BEGIN and END lines and join the rest to a single line/string
public_key=$(grep -v "PUBLIC" jwkscd_key_rsa_pem.pub | tr -d '\n')
# Step 2: Delete the first 44 and last 6 characters
public_key_trimmed=${public_key:44:-6}
# Step 3: Change any + and / characters to - and _ respectively
public_key_modified=$(echo "$public_key_trimmed" | tr '+/' '-_')
# Output the modified public key
# echo "$public_key_modified"
PUBLIC_KEY=$public_key_modified
# just needs to be random and match what's in the header with what's on the URL
KID=$(openssl rsa -in jwkscd_key -pubout -outform DER | openssl dgst -sha256 -binary | openssl enc -base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
echo "Creating jwks.json"
cat <<EOF > jwks.json
{
  "keys": [
    {
      "kty": "RSA",
      "alg": "RS256",
      "use": "sig",
      "kid": "$KID",
      "n": "$PUBLIC_KEY",
      "e": "AQAB"
    }
  ]
}
EOF
echo "JWKS file created: jwks.json"

echo "Saving Key Id as jwkscd_key_id_$TIMESTAMP in Secrets Manager"
# Save the Key ID with timestamp
echo $KID > jwkscd_key_id_$TIMESTAMP
gcloud secrets create jwkscd_key_id_$TIMESTAMP --data-file=jwkscd_key_id_$TIMESTAMP
echo "Cleaning up key files as we have saved them in Secrets Manager."
# Step 4: Clean up key files
rm jwkscd_key jwkscd_key.pub jwkscd_key_rsa_pem.pub jwkscd_key_id_$TIMESTAMP
echo "Key files deleted successfully."
# Step 5: Deploy to Google Cloud Run if --deploy=true
if [[ "$DEPLOY" == "true" ]]; then
  echo "Creating deployment Dockerfile for JWKS"
  # Create a folder called deploy
  mkdir -p deploy
  # Copy the jwks.json in there
  cp jwks.json deploy/
  # Create a Dockerfile for an Alpine-based NGINX container
cat <<EOF > deploy/Dockerfile
    FROM nginx:alpine
    COPY jwks.json /usr/share/nginx/html/jwks.json
    COPY jwks.json /usr/share/nginx/html/index.html
EOF
  cd deploy
  echo "Deploying As A Cloud Run Service [$service_name] from the directory ./deploy"
  gcloud run deploy "$service_name" \
    --source . \
    --region "$REGION" \
    --project "$PROJECT_ID" \
    --allow-unauthenticated \
    --port=80 \
    --memory 128Mi

  deploy_status=$? #get the status

  # Check the status of the deployment
  if [ "$deploy_status" -eq 0 ]; then
    cd -
    echo "Successfully deployed the service [$service_name]."
    echo "Please access jwks.json using the following url"
    # Get the service URL
    service_url=$(gcloud run services describe "$service_name" --region "$REGION" --format="value(status.url)")
    echo "JWKS URL: $service_url/jwks.json"    
  else
    cd -
    echo "Failed to deploy the service [$service_name]."
    exit 1
  fi
    
fi