#!/bin/bash
# (c) charles boatwright
# 
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

function set_options() 
{

  if [[ -z $PKIDIR ]] 
    then
    PKIDIR=/etc/ssl
  fi
  
  
  if  [[ -z $WEBROOT ]]
    then 
    WEBROOT="/srv/datavol"
  fi
  
  
  if [[ -z $APACHECONF ]]
    then
    APACHECONF=/etc/apache2
  fi

  if [[ -z $APACHEUSER ]] 
    then 
     APACHEUSER=www-data
  fi
  
  if [[ -z $APACHEGROUP ]] 
    then 
    APACHEGROUP=www-data
  fi

  if [[ -z $TEMPLATE ]] 
  then
    TEMPLATE=ssl-template
  fi
  
  echo $1

  if [[ -z $1 ]] 
    then
    echo This tool sets up a self signed cert for apache2.2 or 
    echo higher i.e. requires SNI
    echo please supply fqdn to build a config
    echo 
    echo usage is 
    echo $0 www.example.com
    echo or 
    echo $0 clean fqdn to clean up
    echo
    echo these are the options over ride them with
    echo OPTION=/foo/bird/ $0 fqdn
    echo default values are 
    echo PKIDIR is $PKIDIR 
    echo WEBROOT is $WEBROOT 
    echo APACHECONF is $APACHECONF 
    echo APACHEUSER is $APACHEUSER 
    echo APACHEGROUP is $APACHEGROUP 
    echo TEMPLATE is $TEMPLATE
    exit 1

  fi

  if [[ "$1" == "maketemplate" ]] 
  then
    echo Stompin\' yo ssl-template file
    cat > ssl-template <<EOF

<IfModule mod_ssl.c>

<VirtualHost *:443>
        ServerName FQDN
        ServerAdmin webmaster@localhost

        SSLEngine on
        SSLCertificateFile PKIDIR/certs/FQDNFILE.crt
        SSLCertificateKeyFile PKIDIR/private/FQDNFILE.key
        SetEnvIf User-Agent ".*MSIE.*" nokeepalive ssl-unclean-shutdown
#       CustomLog logs/ssl_request_log \
#         "%t %h %{SSL_PROTOCOL}x %{SSL_CIPHER}x \"%r\" %b"

        ServerName FQDN
        ServerAdmin webmaster@localhost

        ErrorLog ${APACHE_LOG_DIR}/FQDNFILE-error.log

        # Possible values include: debug, info, notice, warn, error, crit,
        # alert, emerg.
	LogLevel warn

        CustomLog ${APACHE_LOG_DIR}/FQDNFILE-access.log \
          "%t %h %{SSL_PROTOCOL}x %{SSL_CIPHER}x \"%r\" %b"


        DocumentRoot "WEBROOT/FQDN/htdocs"

        <Directory "WEBROOT/FQDN/htdocs">
              Options +Indexes
                AuthType Basic
                AuthName "huh?"
                AuthUserFile WEBROOT/htaccess-FQDNFILE
                Require valid-user

	</Directory>
        <LocationMatch "/(data|conf|bin|inc)/">
		Order allow,deny
		Deny from all
                Satisfy All
        </LocationMatch>

</VirtualHost>
</IfModule>
EOF

  exit 0
  fi
 
  if [[ -f $TEMPLATE ]]
  then
    :
  else 
    echo You gotta have a template file!  The default template file is $TEMPLATE
    echo use the source, view the source.  you can build a template in cwd with
    echo $0 maketemplate
    exit 1 
  fi

  if [[ "$1" == "clean" ]] 
  then
    CLEANUP=yes
    echo cleanup on aisle 3
    shift 
  fi



  FQDN=$1

  if [[ -z $FQDN ]]
  then 
    echo Cleaning requires a FDQN as well.
    exit 1
  fi
  
  FQDNFILE=`echo $1 | sed y/./-/`

}

function build_vhost () {

  sudo mkdir -p $WEBROOT/$FQDN/htdocs
  sudo chown -R $APACHEUSER:$APACHEGROUP $WEBROOT/$FQDN
  touch $FQDN

  cat ssl-template | sed s/FQDNFILE/$FQDNFILE/ | sed s/FQDN/$FQDN/ | sed s.PKIDIR.$PKIDIR. | sed s.WEBROOT.$WEBROOT. > $FQDN
  sudo cp $FQDN $APACHECONF/sites-available/
  sudo ln -s $APACHECONF/sites-available/$FQDN $APACHECONF/sites-enabled/099-$FQDN
  
}


function cert_attrib()
{
  echo --
  echo  "US" 
  echo  "CA" 
  echo  "San Francisco" 
  echo  "org" 
  echo  $FQDN 
  echo  "hostmaster@$FQDN" 
  
}


function config_ssl () {

#  echo ------ building cert and key without passphrase


  PEMKEY=`mktemp openssl.XXXXX`
  PEMCERT=`mktemp openssl.XXXXX`

  trap "rm -f $PEMKEY $PEMCERT" SIGINT

  cert_attrib | openssl req -newkey rsa:2048 -keyout $PEMKEY -nodes -x509 -days 365 -out $PEMCERT 2> /dev/null
  cat $PEMKEY > $FQDNFILE.key
  echo "" >> $FQDNFILE.key
  cat $PEMCERT > $FQDNFILE.crt
  echo "" >> $FQDNFILE.crt

  rm -f $PEMKEY $PEMCERT

  sudo cp $FQDNFILE.key $PKIDIR/private
  sudo cp $FQDNFILE.crt $PKIDIR/certs
  
}


function cleanup() 
{
  
  sudo rm -rf $WEBROOT/$FQDN
  sudo rm -f $FQDN $APACHECONF/sites-available/$FQDN $APACHECONF/sites-enabled/099-$FQDN

  sudo rm -f $FQDNFILE.key $PKIDIR/private/$FQDNFILE.key $FQDNFILE.crt $PKIDIR/certs/$FQDNFILE.crt

  
}



set_options $@

if [[ "$CLEANUP" == "yes" ]]
  then
  echo cleaning up!
  cleanup
  exit 0
else
  config_ssl
  build_vhost
fi