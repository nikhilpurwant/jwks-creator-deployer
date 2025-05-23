# jwks-creator-deployer
Creates a jwks.json with a keyset. Optionally allows deploying it as a [Cloud Run](https://cloud.google.com/run) service.

<details>

<summary>Click to read more about JWKS URLs</summary>

### JWKS URLs

A **JWKS URL** (JSON Web Key Set URL) is a publicly accessible HTTPS endpoint that provides a list of cryptographic public keys used by an authorization server or identity provider to sign JSON Web Tokens (JWTs).

Here's a breakdown of what that means and why it's important:

* **JSON Web Key Set (JWKS):** A JWKS is a JSON (JavaScript Object Notation) data structure that represents a set of JSON Web Keys (JWKs). Each JWK represents a single cryptographic key, usually a public key.
* **JSON Web Key (JWK):** A JWK is a JSON object that represents a cryptographic key. It includes properties like the key type (`kty`), the intended use (`use`, e.g., `sig` for signature verification), the algorithm (`alg`), a key ID (`kid`), and the actual key material (e.g., `n` and `e` for an RSA public key).
* **Purpose of the JWKS URL:**
    * **JWT Verification:** When an application (a "relying party" or "client") receives a JWT from an authorization server, it needs to verify the token's signature to ensure its authenticity and integrity (that it hasn't been tampered with).
    * **Dynamic Key Discovery:** Instead of having to hardcode public keys, the application can fetch the JWKS from the provided URL. This allows the authorization server to rotate its signing keys without requiring clients to update their configurations.
    * **Key Rotation:** Security best practices recommend regularly rotating cryptographic keys. The JWKS URL facilitates this process by providing a centralized and dynamic way for clients to discover the latest public keys.
* **Typical Location:** JWKS URLs are often found at a "well-known" location on the authorization server, such as `https://<server_domain>/.well-known/jwks.json`. This makes it easy for clients to find the keys.
* **How it Works:**
    1.  An authorization server signs a JWT using its private key. The JWT's header will typically include a `kid` (key ID) that identifies which specific key in the JWKS was used for signing.
    2.  An application receives the JWT.
    3.  The application then sends an HTTP GET request to the authorization server's JWKS URL.
    4.  The server responds with the JWKS (a JSON document containing one or more public keys).
    5.  The application uses the `kid` from the JWT header to find the corresponding public key in the retrieved JWKS.
    6.  Finally, the application uses that public key to verify the JWT's signature.

In essence, the JWKS URL acts as a public repository where authorization servers publish their public keys, allowing other applications to securely verify the digital signatures of the JWTs they issue.

</details>

## Functionality
The script `jwks-create-deploy.sh` does the following

1. Creates an RSA key pair
2. Creates a JWKS key out of the key pair created
3. Saves the public and the private key along with JWKS kid in the secret manager for later referene and backup.
4. If parameter `deploy=true` then it deployes the `jwks.json` as a Cloud Run service (make sure you provide `region` and `project-id` as explained [below](#2-create-and-deploy-jwksjson-as-an-endpoint-cloud-run-service))

## Usage Instructions

Running this script in Google Cloud shell is highly recommended, however you can also use your local (Linux / Mac) machine.
Make sure that [Secret Manager](https://cloud.google.com/security/products/secret-manager) and [Cloud Run](https://cloud.google.com/run) APIs are enabled in the project.
Also, the user executing the script must have permissions to create secrets in Secret Manager and to deploy the Cloud Run service.

> 🪧 **NOTE:**  
> Depending on your use case (only create / create and deploy) - carry out either 1 or 2 from below.

### 1. Only create the jwks.json

Run the following commands

```bash
git clone https://github.com/nikhilpurwant/jwks-creator-deployer.git
cd jwks-creator-deployer
chmod +x jwks-create-deploy.sh
# run the script after updating the parameter - project-id
./jwks-create-deploy.sh --project-id=<GCP Project Id for the Cloud Run Service>
```

You should get a `jwks.json` in the same directory. You can choose to host it using hosting provider of your choice.

Moreover, the following secrets are created

1. `jwkscd_private_key_<TIMESTAMP>` - Later this can be used to sign a request
2. `jwkscd_public_key_<TIMESTAMP>` - Saved for reference
3. `jwkscd_key_id_<TIMESTAMP>` - Saved for reference


### 2. Create and Deploy jwks.json as an endpoint (Cloud Run Service)
Run the following commands

```bash
git clone https://github.com/nikhilpurwant/jwks-creator-deployer.git
cd jwks-creator-deployer
chmod +x jwks-create-deploy.sh
# run the script after updating the parameters - project-id and region.
./jwks-create-deploy.sh --deploy=true --region=<e.g. us-central1> --project-id=<GCP Project Id for the Cloud Run Service>
```

Creates the same secrets as [1](#1-only-create-the-jwksjson).
