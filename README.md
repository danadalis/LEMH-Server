## **LEMH Server on Ubuntu 15.04 Vivid**
### Nginx Compiled from Source, HHVM, MariaDB 10, FastCGI Cache, HTTP2 support, and CloudFlare SSL with a Self-Signed Cert

We're going to walk through a basic LEMH stack install for hosting WordPress sites. As you might have been hearing as of late, Nginx, HHVM, and MariaDB makes WordPress run faster than other options, so building a setup like this will usually get you the most bang for your hosting buck. In addition we'll also include FastCGI Cache, a rather unique method of file caching which is built right into Nginx. By using FastCGI Cache, we're bypassing the more resource intensive solutions based off PHP and WordPress like W3 Total Cache or WP Super Cache. Finally, we'll be self-signing an SSL certificate since we're going to be using a free SSL certificate issued by CloudFlare.
 
*Please Note: We're building this off a RamNode VPS using their Ubuntu 15.04 Vivid 64-bit image with 512MB RAM. Your mileage may vary depending on your chosen host.*
 
----------

### **Basics**
##### **Initial setup**
```
apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y
apt-get install autotools-dev build-essential checkinstall curl debhelper dh-systemd libbz2-dev libexpat-dev  libgd2-noxpm-dev libgd2-xpm-dev libgeoip-dev libgeoip-dev libluajit-5.1-dev libmhash-dev libpam0g-dev libpcre3 libpcre3-dev libpcrecpp0 libperl-dev libssl-dev libxslt-dev libxslt1-dev nano openssl po-debconf software-properties-common sudo tar unzip wget zlib1g zlib1g-dbg zlib1g-dev -y
sudo locale-gen en_US.UTF-8
export LANG=en_US.UTF-8
```
##### **Removing Stuff We Don't Need**
```
sudo apt-get remove --purge mysql-server mysql-client mysql-common apache2* php5*
sudo rm -rf /var/lib/mysql
sudo apt-get autoremove -y && sudo apt-get autoclean -y
```
##### **Changing SSH Port**
```
nano /etc/ssh/sshd_config
service ssh restart
```

----------

### **Nginx**
Since HTTP2 requires an OpenSSL version of 1.0.2 or greater, we're going to compile Nginx from source so we can take advantage of this. Even though CloudFlare isn't currently supporting HTTP2 on their end, we'll be ready when they do.

##### **Downloading**
First we'll need to download the latest versions of Nginx and the various modules we're using.
You'll want to check their sites to ensure you're downloading the latest version.
Get the latest versions at: [Nginx](http://nginx.org/en/download.html), [OpenSSL](https://www.openssl.org/source/), [Headers More Module](https://github.com/openresty/headers-more-nginx-module/tags), and [Nginx Cache Purge Module](http://labs.frickle.com/nginx_ngx_cache_purge/)
```
cd /usr/src/
wget http://nginx.org/download/nginx-1.9.6.tar.gz
tar -xzvf nginx-1.9.6.tar.gz
wget https://github.com/openresty/headers-more-nginx-module/archive/v0.28.tar.gz
tar -xzf v0.28.tar.gz
wget http://labs.frickle.com/files/ngx_cache_purge-2.3.tar.gz
tar -xzf ngx_cache_purge-2.3.tar.gz
wget https://www.openssl.org/source/openssl-1.0.2d.tar.gz
tar -xzf openssl-1.0.2d.tar.gz
```

##### **Installing Nginx**
Now it's time to compile Nginx using the parts we've downloaded. Don't forget to change the openssl, cache purge, and more headers module versions inside of the ./configure command.
```
cd nginx-1.9.6
./configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --pid-path=/var/run/nginx.pid --lock-path=/var/lock/nginx.lock --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-fastcgi-temp-path=/var/lib/nginx/fastcgi --user=www-data --group=www-data --without-mail_pop3_module --with-openssl=/usr/src/openssl-1.0.2d --without-mail_imap_module --without-mail_smtp_module --without-http_uwsgi_module --without-http_scgi_module --without-http_memcached_module --with-http_ssl_module --with-http_stub_status_module --with-http_v2_module --with-debug --with-pcre-jit --with-ipv6 --with-http_stub_status_module --with-http_realip_module --with-http_auth_request_module --with-http_addition_module --with-http_dav_module --with-http_flv_module --with-http_geoip_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_image_filter_module --with-http_perl_module --with-http_sub_module --with-http_xslt_module --with-mail --with-mail_ssl_module --with-stream --with-stream_ssl_module --with-threads --add-module=/usr/src/ngx_cache_purge-2.3 --add-module=/usr/src/headers-more-nginx-module-0.28
make
make install
```
Double check that we've got everything installed correctly by using the `nginx -Vv` command. This will also list all installed modules, and your openssl version.

##### **Creating Directories and Setting Permissions** 
Here we're going to ensure that the right folders are in place for our config. In addition, since we might be hosting multiple domains on this server, we've told our `yourdomain.com.conf` files to log to a dedicated folder inside `/var/log`, just like Nginx or HHVM.
```
sudo mkdir -p /var/www/html
sudo mkdir -p /var/lib/nginx/fastcgi
sudo mkdir -p /etc/nginx/ssl
sudo mkdir -p /etc/nginx/conf.d
sudo mkdir -p /var/cache/nginx
sudo mkdir -p /var/log/domains
sudo chown -hR www-data:www-data /var/log/domains/
sudo rm -rf /etc/nginx/sites-enabled
sudo rm -rf /etc/nginx/sites-available
```

##### **Automatically Starting Nginx**
Now that we've installed Nginx, we'll need to make it start up automatically each time the server reboots. Ubuntu 15.04 uses SystemD to handle bootup processing, so that's what we'll be working with.
```
sudo nano /lib/systemd/system/nginx.service
```
Now paste in the code below, then save.
```
# Stop dance for nginx
# =======================
#
# ExecStop sends SIGSTOP (graceful stop) to the nginx process.
# If, after 5s (--retry QUIT/5) nginx is still running, systemd takes control
# and sends SIGTERM (fast shutdown) to the main process.
# After another 5s (TimeoutStopSec=5), and if nginx is alive, systemd sends
# SIGKILL to all the remaining processes in the process group (KillMode=mixed).
#
# nginx signals reference doc:
# http://nginx.org/en/docs/control.html
#
[Unit]
Description=A high performance web server and a reverse proxy server
After=network.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
```
Finally, let's double check that it's working, and then turn on Nginx.
```
sudo systemctl enable nginx.service
sudo systemctl start nginx.service
sudo systemctl status nginx.service
```

In the future, you can restart Nginx by typing `sudo service nginx restart`

----------

### **HHVM**
```
wget -O - http://dl.hhvm.com/conf/hhvm.gpg.key | sudo apt-key add -
echo deb http://dl.hhvm.com/ubuntu vivid main | tee /etc/apt/sources.list.d/hhvm.list
sudo apt-get update && apt-get install hhvm -y
```

##### **Setting HHVM to Load at Boot** 
```
sudo update-rc.d hhvm defaults
sudo /usr/bin/update-alternatives --install /usr/bin/php php /usr/bin/hhvm 60
```

##### **Set HHVM to Use Unix Sockets**
Since Unix sockets are faster, and we like that, we're going to want to make 2 quick changes to switch over to using sockets instead of TCP.
```
sudo nano /etc/hhvm/server.ini
```
replace `hhvm.server.port = 9000` with `hhvm.server.file_socket=/var/run/hhvm/hhvm.sock`

Since our HHVM.conf file already has sockets enabled, we don't need to edit anything else. But on another server you'd need to replace `fastcgi_pass   127.0.0.1:9000;` with `fastcgi_pass unix:/var/run/hhvm/hhvm.sock;`

##### **PHP.ini Settings** 
Let's set some quick variables so that HHVM has good timeout and filesize limits for WordPress. Feel free to adjust these based on your needs
```
sudo nano /etc/hhvm/php.ini
```
Paste this under `; php options`

```
max_execution_time = 300
max_input_time = 60
memory_limit = 128M
post_max_size = 22M
upload_max_filesize = 22M
```

##### **Get Your PHP Installation Info** 
The latest version of HHVM now supports the `phpinfo` command, so you'll be able to get a lot of useful info about your installation. Here we're going to write a very basic php file that will give us this information. We're going to send it straight to your server's default folder, which will be `/var/www/html`. By contrast, domains will be using `/var/www/yourdomain.com/html`.
```
echo "<?php phpinfo(); ?>" > /var/www/html/phpinfo.php
```

Point your browser to http://ipa.ddr.ess/phpinfo.php.

----------

#### **.conf Files** 
Now it's time to move [nginx.conf](https://github.com/VisiStruct/LEMH-Server/blob/master/nginx/nginx.conf "/etc/nginx/nginx.conf"), [wpsecurity.conf](https://github.com/VisiStruct/LEMH-Server/blob/master/nginx/wpsecurity.conf "/etc/nginx/wpsecurity.conf"), [fileheaders.conf](https://github.com/VisiStruct/LEMH-Server/blob/master/nginx/fileheaders.conf "/etc/nginx/fileheaders.conf"), and [hhvm.conf](https://github.com/VisiStruct/LEMH-Server/blob/master/nginx/hhvm.conf "/etc/nginx/hhvm.conf") into `/etc/nginx/`. 

You'll also want to move [default.conf](https://github.com/VisiStruct/LEMH-Server/blob/master/conf.d/default.conf "/etc/nginx/conf.d/default.conf") into `/etc/nginx/conf.d/`. 

Then restart HHVM and Nginx.
```
sudo service nginx restart && sudo service hhvm restart
```
##### **Set Nginx Worker Processes**
Set worker processes to the number of CPUs you have available. We can find this information by using the `lscpu` command and editing the `nginx.conf` file. Enter whatever value `lscpu` lists under `CPU(s):   `
```
lscpu
sudo nano /etc/nginx/nginx.conf
```

----------

### **MariaDB 10** 
We're using the latest version of MariaDB instead of MySQL, as the performance is great with WordPress.
##### **Add MariaDB Repo** 
```
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
sudo add-apt-repository 'deb http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.0/ubuntu vivid main'
```

##### **Installing MariaDB** 
At the end of this installation, MariaDB will ask you to set your password, don't lose this!
```	
sudo apt-get update && apt-get install mariadb-server -y
```
Make sure that MariaDB has upgraded to the latest files by running this again.
```
sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get dist-upgrade -y
```

##### **Securing MariaDB** 
MariaDB includes some test users and databases that we don't want to be using in a live production environment. Now that MariaDB is installed, run this command. Since we've already set the admin password, we can hit `N` to the first option. You'll want to hit `Y` to the rest of the questions.
```
mysql_secure_installation
```
Finally, you can make sure MariaDB is installed and working correctly by logging using the following command.
##### **Log into MariaDB** 
Test to make sure things are working by logging in to MySQL, then exiting.
```
sudo mysql -v -u root -p
```
You can exit MariaDB by typing `exit`

### **phpMyAdmin**
Since phpMyAdmin is already available through the default Ubuntu 15.04 repos, this part is really easy. We're pointing our phpMyAdmin location to `/var/www/html`, which will make it available at your server's IP address. Alter the lines below to reflect a different location, such as a behind a domain.
```
sudo apt-get install phpmyadmin -y
sudo update-rc.d -f apache2 remove
sudo update-rc.d -f php5 remove
sudo ln -s /usr/share/phpmyadmin /var/www/html
```

Point your browser to http://ipa.ddr.ess/phpmyadmin

----------

### **WordPress** 
##### **Creating a MySQL Database** 
We're going to create the database by command line because we're cool. You can also do this directly though phpMyAdmin, if you're not as cool. Replace the `database`, `user`, and `password` variables in the code below.
```
mysql -u root -p
CREATE DATABASE database;
CREATE USER 'user'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON database.* TO 'user'@'localhost';
FLUSH PRIVILEGES;
exit
```

##### **Install WordPress** 
We're going to create a few directories needed for WordPress, set the permissions, and download WordPress. We're also going to just remove the Hello Dolly plugin, because obviously.
```
sudo mkdir -p /var/www/yourdomain.com/html						
cd /var/www/yourdomain.com/html
wget http://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz
mv wordpress/* .
rmdir /var/www/yourdomain.com/html/wordpress
sudo rm -f /var/www/yourdomain.com/html/wp-content/plugins/hello.php
sudo mkdir -p /var/www/yourdomain.com/html/wp-content/uploads
```
It's time to upload any files you might have (themes, plugins, uploads, etc, wp-config, etc).

##### **Secure WordPress** 
 Once you're done uploading files, we'll want to secure WordPress' directory and file permissions.
```
find /var/www/yourdomain.com/html/ -type d -exec chmod 755 {} \;
find /var/www/yourdomain.com/html/ -type f -exec chmod 644 {} \;
sudo chown -hR www-data:www-data /var/www/yourdomain.com/html/
```

##### **Install Nginx Site File**
Now that we've got the directory structure of your domain squared away, we'll need to enable it in Nginx.

Copy the contents of [yourdomain.com.conf](https://github.com/VisiStruct/LEMH-Server/blob/master/conf.d/yourdomain.com.conf "/etc/nginx/conf.d/yourdomain.conf") into your text editor of choice. You'll want to replace all instances of `yourdomain.com` to reflect your domain. Save the file and move it to `/etc/nginx/conf.d/`

----------

### **Self-Signed SSL Certificate** 
Here we're going to generate a self-signed SSL certificate. Since we're using CloudFlare anyway, we're going to use a *FREE* SSL certificate through them. You'll need to set CloudFlare's SSL certificate status to `Full` for this to work.
```
sudo openssl req -x509 -nodes -days 365000 -newkey rsa:2048 -keyout /etc/nginx/ssl/yourdomain.com.key -out /etc/nginx/ssl/yourdomain.com.crt
cd /etc/nginx/ssl
openssl dhparam -out yourdomain.com.pem 2048
```

----------

### **FastCGI Cache Conditional Purging** 

You'll want a way to purge the cache when you make changes to the site, such as editing a post, changing a menu, or deleting a comment.

##### **Nginx Cache WordPress Plugin**

We like RTCamp's Nginx Helper Plugin. You'll want to go to the WordPress Dashboard, then Settings/ Nginx Helper. Turn on purging, and select the conditions you want to trigger the purge. Finally, select the timestamp option at the bottom to display your page's build time in the source code.
Download: [Nginx Helper](https://wordpress.org/plugins/nginx-helper/)

----------

### **Checking FastCGI Cache** 
It's always a good idea to make sure that what you think is working is in fact actually working. Since we don't want to serve cached versions of every page on the site, inside `hhvm.conf` we've added a list of pages and cookies that we want to avoid caching. To help shed light on things a bit, we've added the line `add_header X-Cached $upstream_cache_status;` inside `/etc/nginx/hhvm.conf`. This will tell us with certainty whether or not the page being served is the cached version. 

We can check the status of any page by viewing the headers that are sent along when you visit it. To do this, you can use a variety of methods. You can use the `CURL` command inside your terminal by typing `curl -I https://yourdomain.com`. Plugins exist for Mozilla FireFox and Google chrome that will make things a bit easier, we prefer Live HTTP Headers for Google Chrome https://chrome.google.com/webstore/detail/live-http-headers/iaiioopjkcekapmldfgbebdclcnpgnlo?utm_source=chrome-app-launcher-info-dialog.

You'll encounter 4 different messages based on the cache type. `X-Cached: HIT`, `X-Cached: MISS`, `X-Cached: EXPIRED`, or `X-Cached: BYPASS`. 

######X-Cached: HIT
You're being served a cached version of the page.

######X-Cached: MISS 
The server did not have a cached copy of that page, so you're being fed a live version instead. Initially all pages will show as `X-Cached: MISS`. Once they've been visited, Nginx will store a copy of that code for future visitors.

######X-Cached: EXPIRED 
The version that was stored on the server is too old, and you're seeing a live version instead.

######X-Cached: BYPASS 
We've told Nginx skip caching a page if it matches a set of criteria. For example, we don't want to cache any page beginning with `WP-`, or any page visited by a logged in user or recent commenter. Depending on the plugins you're running, there may be additional things you'll want to set to avoid being cached.

----------				

### **Optional Stuff** 
##### **WooCommerce and FastCGI Cache** 
We really don't want Nginx to cache anything related to WooCommerce, as this could result in a customer's information being fed to others. So we're going to tackle this 3 different ways. Our `hhvm.conf` file reflects these changes already, just uncomment the stuff you want to enable by removing the `#` from those lines.

As you can see below, we're checking a number of locations for pages that we don't want Nginx to cache. The variables `/shop.*|/cart.*|/my-account.*|/checkout.*` should reflect WooCommerce's default page nstructure.
```
if ($request_uri ~* "(/shop.*|/cart.*|/my-account.*|/checkout.*|/addons.*|/wp-admin/|/xmlrpc.php|wp-.*.php|/feed/|index.php|sitemap(_index)?.xml|[a-z0-9_-]+-sitemap([0-9]+)?.xml)") {        
	set $no_cache 1;
	}
```
	
We'll want to add the variable `wp_woocommerce_session_[^=]*=([^%]+)%7C`. This avoids most woocommerce sessions.
```
if ($http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_no_cache|wordpress_logged_in|wp_woocommerce_session_[^=]*=([^%]+)%7C") {        
	set $no_cache 1;
	}
```

We'll also want to to turn on a check to see if a visitor has an item in their cart.
```
if ( $cookie_woocommerce_items_in_cart != "1" ) {
	set $skip_cache 1;
}
```

##### **HHVM and Nginx Timeouts** 
If you're doing an import into WordPress, or something else that will be processing for along time, you'll want to increase the timeout variables for HHVM and Nginx. Change these temporarily.
###### **Nginx** 
```
sudo /etc/nginx/fastcgicache.conf
```
Change `fastcgi_read_timeout 300;` from `300` to `2000`

###### **HHVM** 
```
sudo nano /etc/hhvm/php.ini
```
Change `max_execution_time = 300` to `2000`
Change `max_input_time = 60` to  `2000`

Be sure change them back when you're done.

##### **Making JetPack's Photon Module Work Better with SSL**
JetPack is widely used in WordPress installations for good reason. The Photon module doesn't always play nice with WordPress installations that force SSL all the time, resulting in pictures that don't get served by Photon's CDN. We can create an Nginx rewrite that feeds images over an unsecure connection, but that's not optimal and a waste of processing cycles. A simple code addition tells Photon to stop rejecting images that are served via HTTPS.

Edit your theme's `functions.php`. Add this code towards the top somewhere nice. If you're using a theme that updates frequently, you'll want to add a child theme. Otherwise you'll need to do this edit every time you update.
```
sudo nano /var/www/yourdomain.com/html/wp-content/themes/your-theme-folder/functions.php
```
Add this code towards the top somewhere.
```
add_filter( 'jetpack_photon_reject_https', '__return_false' );
```
### **Done!** 

*Naturally, this tutorial is always subject to change, and could include mistakes or vulnerabilities that might result in damage to your site by malicious parties. We make no guarantee of the performance, and encourage you to read and thoroughly understand each setting and command before you enable it on a live production site.*

*If we've helped you, or you've given up and want to hire a consultant to set this up for you, visit us at https://VisiStruct.com*
