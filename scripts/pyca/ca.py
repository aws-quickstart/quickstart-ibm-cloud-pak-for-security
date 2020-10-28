# Internal certificate authority
from certauth.certauth import CertificateAuthority
import json
import os
import sys

def split_certs(cert_data):
	"""Splits private key and certificate..."""

	private_key_start_index = cert_data.find("-----BEGIN PRIVATE KEY-----")
	private_key_end_index = cert_data.find("-----END PRIVATE KEY-----")
	private_key = cert_data[private_key_start_index:private_key_end_index + 25]
	cert = cert_data[private_key_end_index + 26:]

	return private_key, cert

def generate_certs(host, w):
	"""Generates private.key, cert.crt, and ca-bundle.crt..."""

	WORKDIR = "/".join(__file__.split("/")[:-1])

	with open (WORKDIR + "/config.json", "r") as config_file:
		CONFIG = json.load(config_file)

	path = "."

	ca = CertificateAuthority(CONFIG["CERT_AUTH_NAME"], 
							  CONFIG["CERT_AUTH_ROOT_FILE"],
							  cert_cache=path)

	cert, key = ca.load_cert(host, wildcard=w)

	## Extract root CA and host private keys and certificates from pem files ##
	with open(CONFIG["CERT_AUTH_ROOT_FILE"], "r") as py_ca_file:
		py_ca_data = "".join(py_ca_file.readlines())
	ca_private_key, ca_root_cert = split_certs(py_ca_data)
	with open(path + "/" + host + ".pem", "r") as host_file:
		host_data = "".join(host_file.readlines())
	host_private_key, host_cert = split_certs(host_data)

	## Output certificates to host folder ##
	with open(path + "/ca.crt", "w+") as py_ca_root_cert_file:
		py_ca_root_cert_file.write(ca_root_cert)
	print(f"Generating " + path + "/ca_bundle.crt")

	with open(path + "/private.key", "w+") as host_private_key_file:
		host_private_key_file.write(host_private_key)
	print(f"Generating " + path + "/private.key")

	with open(path + "/cert.crt", "w+") as host_cert_file:
		host_cert_file.write(host_cert)
	print(f"Generating " + path + "/cert.crt")

	with open(path + "/domain-cert.crt", "w+") as concat_cert_file:
		concat_cert_file.write(ca_root_cert + host_cert)
	print(f"Generating " + path + "/concat.crt")

	print("Finished!")

domain = sys.argv[1]
wildcard = None

if domain[0] == "*":
	wildcard = True
else:
	wildcard = False

print(f"Generating certificates with pyCertificate Authority for {domain} using wildcard {wildcard}")
generate_certs(domain, wildcard)
