#!/bin/bash

# load configuration
source acme.sh.env

# get domain name from argument
domain=$1

# check if domain name was specified
if [[ $domain == "" ]]; then
    echo "Please specify domain name."
    exit 1
fi

acmelogfile=./acme_$domain.log
echo "" > $acmelogfile

# make sure a directory exists for the domain name
certs="$CERTSDIR/$domain"
mkdir -p $certs

# run acme.sh end generate the certificate
echo "Issuing SSL certificate for $domain"
/opt/acme.sh/acme.sh --issue --dns dns_nsupdate --challenge-alias $ALIASDOMAIN --dnssleep $SLEEPTIME --force --log -d $domain -d *.$domain --cert-file $certs/cert.cer --key-file $certs/key.key --fullchain-file $certs/fullchain.cer 2>&1  >> $acmelogfile &

# wait for the command to finish
wait

# check if issuing was successfull
issuedsuccess=$(cat $acmelogfile | grep "Cert success." | wc -l)

# if successful restart all services
if [ "$issuedsuccess" -eq "1" ]; then
    echo "Certificate issued successfully!"
else
    echo "Error generating certificate!"
fi
