#############################################################
### This file is protected by your Rudder infrastructure. ###
### Manually editing this file will lead your Rudder      ###
### infrastructure to change back the server’s            ###
### configuration and raise a compliance alert.           ###
#############################################################

<VirtualHost *:80>
	ServerAdmin webmaster@localhost

	# Rudder webapp
	RewriteEngine on
	RewriteRule   ^/$  /rudder [R]

	ProxyPass         "/rudder" "http://localhost:8080/rudder"
	ProxyPassReverse  "/rudder" "http://localhost:8080/rudder"
	ProxyRequests     Off

	# Local reverse proxy authorization override
	# Most unix distribution deny proxy by default (ie /etc/apache2/mods-enabled/proxy.conf in Ubuntu)
	<Proxy http://localhost:8080/rudder*>
		Order deny,allow
		Allow from all
	</Proxy>

	# Nice loading page if the Java server is not ready
	DocumentRoot /opt/rudder/share/load-page
	ErrorDocument 503 /rudder-loading.html

	# Enforce permissive access to the load page directory
	<Directory /opt/rudder/share/load-page>
		Order deny,allow
		Allow From all
	</Directory>
	
	# Expose the server UUID through http
	Alias /uuid /opt/rudder/etc/uuid.hive
	<Directory /opt/rudder/etc>
		Order deny,allow
		Allow from all
	</Directory>

	# WebDAV share to receive inventories
	Alias /inventories /var/rudder/inventories/incoming
	<Directory /var/rudder/inventories/incoming>
		DAV on 
		AuthName "WebDAV Storage" 
		AuthType Basic
		AuthUserFile /opt/rudder/etc/htpasswd-webdav
		Require valid-user
		Order deny,allow
		Allow from $(root_networks_check.networks)
		<LimitExcept PUT>
			Order allow,deny
			Deny from all
		</LimitExcept>
	</Directory>

	# NO access to the API unless you are localhost
	<Location /rudder/api>
		Order deny,allow
		Deny from all
		Allow from localhost
	</Location>

	# Logs
	ErrorLog /var/log/rudder/apache2/error.log
	LogLevel warn
	CustomLog /var/log/rudder/apache2/access.log combined

</VirtualHost>