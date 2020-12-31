# ACMESH-automation

This repository contains basic guide as well as additional resources for [Acme.sh](https://acme.sh/) automation on Linux for DNS-based wildcard domain verification and certificate issuing.

## Prepare BIND DNS server for dynamic updates

### Generate TSIG key pair

To enable dynamic remote updates to your DNS zones, you need to create an authentication key pair that will authorize you to edit certain DNS zones within BIND.

```bash
dnssec-keygen -a HMAC-SHA512 -b 128 -n HOST <KEY NAME>
```

Replace the `<KEY NAME>` with any name you like, e.g. `ssl_update`.

This command will generate two files, one public and one private key.

__Kssl_update.+165+13761.key__
```
ssl_update. IN KEY 512 3 165 K5E2fNueFF85hhlof98LQw==
```

Rename this file to something more simple, e.g. `ssl_update.key`.

__Kssl_update.+165+13761.private__
```
Private-key-format: v1.3
Algorithm: 165 (HMAC_SHA512)
Key: K5E2fNueFF85hhlof98LQw==
Bits: AAA=
Created: 20201231142127
Publish: 20201231142127
Activate: 20201231142127
```

Rename this file to something more simple, e.g. `ssl_update.private`.

### Add the key to BIND and enable remote updates

On your server running BIND, open the main configuration file (`/etc/named.conf`) and add the key definition:

```
key "ssl_update" {
    algorithm hmac-sha512;
    secret "<YOUR KEY HERE>";
};
```

With the above generated key pair example, it would look like this:

```
key "ssl_update" {
    algorithm hmac-sha512;
    secret "K5E2fNueFF85hhlof98LQw==";
};
```

### Enable dynamic updates on your zones

For each DNS zone, where you want to do remote updates, you need to allow updates using the newly defined key:

```
zone "domain1.com" { type master; file "named.domain1.com"; allow-update { key "ssl_update"; }; };
```

### (Recommended) Create special sub-domain for acme.sh

Create one subdomain which will be aliased through all of the other domain names. This will allow you easier maintenance and SSL certificate generation.

- Create a subdomain (zone), e.g. `acmesh_update.domain1.com`, with a short TTL (60 or so for fast changes)
- Allow DNS updates with the generated key in this zone
- Add a CNAME record to all of your domains to serve as an alias for acme.sh - `_acme-challenge         CNAME   _acme-challenge.acmesh_update.domain1.com.`

Now, you only need to grant `allow-update` to one zone, which can host just the TXT records for acme.sh. The scripts are already expecting this, so make sure to change the `ALIASDOMAIN` environment variable.

Now restart BIND to apply the new configuration.

## Set-up acme.sh

Download and install acme.sh from a trusted source. Follow the tutorials specified by the author.

### Create your environment configuration

Copy the contents of the example acme environment and adjust it to your needs. Be sure to set the correct paths for acme.sh, change the nsupdate server connection (the IP address of your DNS server, the path to the generated key file, and the alias domain).

Then you may adjust the wait time of the acme.sh script and the path where SSL certificates will be stored.

```ini
# acme.sh configuration
export LE_WORKING_DIR="/opt/acme.sh"
alias acme.sh="/opt/acme.sh/acme.sh"

# nsupdate configuration
export NSUPDATE_SERVER="1.1.1.1"
export NSUPDATE_KEY="/opt/acme.sh/ssl_update.key"
export ALIASDOMAIN="acmesh_update.domain1.com"

# wait time before checking DNS TXT records and verifying the domain ownership
export SLEEPTIME=1800
# certificate directory path
export CERTSDIR="/data/certs"
```

## Using the scripts

There are two scripts provided that enable easy wildcard certificate generation for multiple domains.

### Simple wildcard certificate generator - `issue_one.sh`

To generate a wildcard certificate for one specific domain name, use the following script. As an argument, pass in the domain name which will be the subject along with it's subdomain wildcard:

```bash
./issue_one.sh special.com
```

This will generate a certificate with the following subjects:

- special.com
- *.special.com

The certificate will have the following path:

```bash
$CERTSDIR/special.com/cert.cer
$CERTSDIR/special.com/key.key
$CERTSDIR/special.com/fullchain.cer
```

### Central certificate with multiple domains - `issue_all.sh`

This script will generate one certificate for all specified domain names. Specify your domain names in the `domains` array at the top of the script.

Each domain will be also added as a wildcard, so with the example configuration, the following domain names will be added to the certificate subject:

- domain1.com
- *.domain1.com
- domain2.com
- *.domain2.com
- domain3.com
- *.domain3.com

The certificate will have the following path:

```bash
$CERTSDIR/all/cert.cer
$CERTSDIR/all/key.key
$CERTSDIR/all/fullchain.cer
```

After the issuing is done, the script will check if a certificate was generated successfully and if yes, the script will restart specified services (e.g. NginX, Postfix, Dovecot, ...).

### Automation using CRON

You may run these scripts from the crontab automatically to refresh your certificates automatically. Just add the needed entries:

```bash
# Acme.sh
0               2               1               *               *               /opt/acme.sh/issue_all.sh
0               2               1               *               *               /opt/acme.sh/issue_one.sh special.com
```
