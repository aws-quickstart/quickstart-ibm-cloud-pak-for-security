"""Custom exception messages for handling error raising.
"""

CODES = {

"SSH_KEYGEN_ERROR":
"""\nThe SSH key for OpenShift failed to be created or enabled. See the 
AWSUtilities module for reference.

METHOD: machine_utils.py/ssh_keygen()

<URL_TO_REFS>
\n""",

"NO_S3_BUCKET_NAME_ERROR":
"""\nAn S3 bucket name (bucket) must be provided to copy items. See the
AWSUtilities module for reference.

METHOD: bucket_utils.py/cp_s3_item()

<URL_TO_REFS>
""",

"NO_S3_PATH_ERROR":
"""\nAn S3 object key (path_to_s3_item) must be provided. See the
AWSUtilities module for reference.

METHOD: bucket_utils.py/cp_s3_item()

<URL_TO_REFS>
""",

"NO_DEST_PATH_ERROR":
"""\nA file destination path (host_dest_path) must be provided. See the
AWSUtilities module for reference.

METHOD: bucket_utils.py/cp_s3_item()

<URL_TO_REFS>
""",

"NO_BOTO_S3_CLIENT_ERROR":
"""\nBoto3 S3 client must be provided. See the
AWSUtilities module for reference.

METHOD: bucket_utils.py/cp_s3_item()

<URL_TO_REFS>
"""

}