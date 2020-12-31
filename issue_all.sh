#!/bin/bash

# load configuration
source acme.sh.env

# domain list
domains=("domain1.com" \
"domain2.com" \
"domain3.com")

acmelogfile=./acme.log
echo "" > $acmelogfile

# generate acme command
command="/opt/acme.sh/acme.sh --issue --dns dns_nsupdate --challenge-alias $ALIASDOMAIN --dnssleep $SLEEPTIME --force "
# add all domains and their wildcards
for index in ${!domains[*]}
do
    echo "Issuing SSL certificate for ${domains[$index]}"
    #mkdir -p $certs/${domains[$index]}
    command="$command -d ${domains[$index]} -d *.${domains[$index]}"
done

# run the command end generate the certificate
eval "$command --cert-file $certs/all/cert.cer --key-file $CERTSDIR/all/key.key --fullchain-file $CERTSDIR/all/fullchain.cer 2>&1 >> $acmelogfile" &

# wait for the command to finish
wait

# check if issuing was successfull
issuedsuccess=$(cat $acmelogfile | grep "Cert success." | wc -l)

# if successful restart all services
if [ "$issuedsuccess" -eq "1" ]; then
    echo "Certificate issued successfully!"
    /usr/bin/systemctl restart nginx
    /usr/bin/systemctl restart dovecot
    /usr/bin/systemctl restart postfix
else
    echo "Error generating certificate!"
fi
