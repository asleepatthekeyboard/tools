#!/bin/bash
# (c) charles boatwright
# 
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or (at
#your option) any later version.
#
#This program is distributed in the hope that it will be useful, but
#WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program. If not, see http://www.gnu.org/licenses/.

function set_options() 
{

  if [[ -z $PKIDIR ]] 
    then
    if [[ "$DISTRO" == "debian" ]]
      then 
      PKIDIR=/etc/ssl

    elif [[ "$DISTRO" == "centos" ]]
      then 
      PKIDIR=/etc/pki/tls
    fi

  fi
  
  
  if  [[ -z $WEBROOT ]]
    then 
    WEBROOT="/srv/datavol"
  fi
  
  
  if [[ -z $APACHECONF ]]
    then
    if [[ "$DISTRO" == "debian" ]]
      then 
      APACHECONF=/etc/apache2
    elif [[ "$DISTRO" == "centos" ]]
      then 
      APACHECONF=/etc/httpd
    fi

  fi

  if [[ -z $APACHEUSER ]] 
    then 
    if [[ "$DISTRO" == "debian" ]]
      then 
      APACHEUSER=www-data
    elif [[ "$DISTRO" == "centos" ]]
      then 
      APACHEUSER=apache
    fi
     
  fi
  
  if [[ -z $APACHEGROUP ]] 
    then 
    if [[ "$DISTRO" == "debian" ]]
      then 
      APACHEGROUP=www-data

    elif [[ "$DISTRO" == "centos" ]]
      then 
	APACHEGROUP=apache
      fi
    
  fi

  if [[ -z $TEMPLATE ]] 
  then
    TEMPLATE=ssl-template
  fi
  
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
    

    ALLOPTS="PKIDIR WEBROOT"
    for OPT in $ALLOPTS; do
	echo $OPT = $"{$OPT}"
    done


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


# this is fugly.  but, this script doesn't get run but once
# per setup.  Deal
function guess_distro ()
{
   grep -i ubuntu /proc/version > /dev/null
   if [ 0 -eq $? ]
   then
     DISTRO=debian
     
   fi
   grep -i debian /proc/version > /dev/null
   if [ 0 -eq $? ]
   then
     DISTRO=debian
   fi
   grep -i centos /proc/version > /dev/null
   if [ 0 -eq $? ]
   then
     DISTRO=centos

   fi
   grep -i redhat /proc/version > /dev/null
   if [ 0 -eq $? ]
   then
     DISTRO=centos

   fi
   if [[ "" == "$DISTRO" ]]
   then
     echo The distribution was not detected.  The files
     echo will be left in the `pwd`. 
     echo Copy to the appropriate directories
   fi
   

}

function build_vhost () {

  sudo mkdir -p $WEBROOT/$FQDN/htdocs
  sudo chown -R $APACHEUSER:$APACHEGROUP $WEBROOT/$FQDN
  touch $FQDN

  cat ssl-template | sed s/FQDNFILE/$FQDNFILE/ | sed s/FQDN/$FQDN/ | sed s.PKIDIR.$PKIDIR. | sed s.WEBROOT.$WEBROOT. > $FQDN

  if [[ "$DISTRO" == "debian" ]]
  then 
    sudo cp $FQDN $APACHECONF/sites-available/
    sudo ln -s $APACHECONF/sites-available/$FQDN $APACHECONF/sites-enabled/099-$FQDN
  elif [[ "$DISTRO" == "centos" ]]
  then 
    sudo cp $FQDN $APACHECONF/conf.d
  fi
    
    
  
}

# this function is likely to become a furball..
# 
function check_deps() 
{
  if [[ "$DISTRO" == "centos" ]]
  then  
    APACHEBIN=httpd
  elif [[ "$DISTRO" == "debian" ]]
  then
    APACHEBIN=apache2
  fi
  
    
  APACHE=`sudo which $APACHEBIN`

  if [ -z $APACHE ]
  then 
    echo apache binary was not found - it could be path issue or
    echo it could be that apache web server is not installed.
    exit 1
  fi
  APACHEVER=`$APACHEBIN -version | grep "Apache/2"`

  if [[ -z $APACHEVER ]]
  then
    echo the version of apache does not seem to be version 2
    $APACHE -version
    exit 1
  
  fi

  # fortunately openssl is usually in the path...
  OPENSSL=`which openssl`
  if [[ -z $OPENSSL ]]
  then
    echo no openssl found.  it needs to be installed
    exit 1
  fi
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

  # just incase umask is loosie goosie
  chmod 600 $FQDNFILE.key
  chmod 640 $FQDNFILE.crt

  rm -f $PEMKEY $PEMCERT

  if [[  $DISTRO ]]
  then
    # explicitly call the file out  (probably should test the 
    # directory first)
    sudo cp $FQDNFILE.key $PKIDIR/private/$FQDNFILE.key
    sudo cp $FQDNFILE.crt $PKIDIR/certs/$FQDNFILE.crt

    # just in case some DOPE set a stupid umask for root
    sudo chmod 600 $FQDNFILE.key
    sudo chmod 640 $FQDNFILE.crt

  fi
}

# DANGER DANGER delects DocRoot!!!!
function cleanup() 
{
  
  sudo rm -rf $WEBROOT/$FQDN


  if [[ "$DISTRO" == "debian" ]]
  then 
    
    echo removing......
    echo $FQDN $APACHECONF/sites-available/$FQDN $APACHECONF/sites-enabled/099-$FQDN $FQDNFILE.key $PKIDIR/private/$FQDNFILE.key $FQDNFILE.crt $PKIDIR/certs/$FQDNFILE.crt

    sudo rm -f $FQDN $APACHECONF/sites-available/$FQDN $APACHECONF/sites-enabled/099-$FQDN $FQDNFILE.key $PKIDIR/private/$FQDNFILE.key $FQDNFILE.crt $PKIDIR/certs/$FQDNFILE.crt
  elif [[ "$DISTRO" == "centos" ]]
  then 
    sudo rm -f $FQDN $APACHECONF/conf.d/$FQDN $FQDNFILE.key $PKIDIR/private/$FQDNFILE.key $FQDNFILE.crt $PKIDIR/certs/$FQDNFILE.crt
  fi

  
}

# FIRE IT UP! FIRE IT UP!



guess_distro
check_deps

set_options $@

if [[ "$CLEANUP" == "yes" ]]
  then
  cleanup
  exit 0
else
  config_ssl
  build_vhost
fi