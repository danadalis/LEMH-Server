## **LEMH Server on Ubuntu 14.04 Trusty**
### Nginx, HHVM, MariaDB 10, FastCGI Cache, and CloudFlare SSL w/Self-Signed Cert

We're going to walk through a basic LEMH stack install, which will be powering a RamNode VPS for hosting WordPress sites. As you might have been hearing as of late, Nginx, HHVM, and MariaDB make WordPress faster than using any combination of Apache, PHP 5.6, or MySQL. So we're going to utilize the easiest methods of getting a config like this working. In addition we'll also include FastCGI Cache, a rather unique method of file caching which is built right into Nginx. By using FastCGI Cache, we're bypassing the more resource intensive solutions based off PHP and WordPress like W3 Total Cache or WP Super Cache. 
 
*Please Note: We're building this off a RamNode VPS using their Ubuntu 14.04 Trusty 64-bit Minimal image with 512MB RAM. Your mileage may vary depending on your chosen host.*
 
----------
### **Basics**
##### **Initial setup**
```
passwd
apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y
apt-get install sudo nano wget curl build-essential zlib1g-dev libpcre3 libpcre3-dev software-properties-common -y
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
We'll be using the nginx-extras found on the Launchpad Nginx Mainline PPA because this comes pre-installed with the More Headers and FastCGI Purge modules. If you need different modules, you'll have to compile Nginx from source instead. 

*NOTE: You'll probably be using an old version of OpenSSL. If you need 1.0.2 or newer you'll also need to compile from source.*

##### **Adding LaunchPad PPA**
```
sudo nano /etc/apt/sources.list.d/nginx.list
```
Paste in 2 lines, then save.

```
deb http://ppa.launchpad.net/nginx/development/ubuntu trusty main 
deb-src http://ppa.launchpad.net/nginx/development/ubuntu trusty main
```
##### **Installing Nginx**
```
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 00A6F0A3C300EE8C
sudo apt-get update && apt-get upgrade -y
sudo apt-get install openssl libssl-dev libperl-dev -y
apt-get install nginx-extras
```
Double check that we've got the latest version installed by using the `nginx -Vv` command. This will also list all installed modules, and your openssl version.
##### **Set Worker Processes**
Set worker processes to the number of CPUs you have available. We can find this information by using the `lscpu` command and editing the `nginx.conf` file. Enter whatever value `lscpu` lists under `CPU(s):  `
```
lscpu
sudo nano /etc/nginx/nginx.conf
```

##### **Creating Directories and Setting Permissions** 
Here we're going to ensure that the right folders are in place for our config. In addition, since we might be hosting multiple domains on this server, we've told our `yourdomain.com.conf` files to log to a dedicated folder inside `/var/log`, just like Nginx or HHVM.
```
sudo mkdir -p /var/www
sudo mkdir -p /var/www/html
sudo mkdir /etc/nginx/ssl
sudo mkdir /var/cache/nginx
sudo mkdir -p /var/log/domains
sudo chown -hR www-data:www-data /var/log/domains/
sudo rm -rf /etc/nginx/sites-enabled
sudo rm -rf /etc/nginx/sites-available
```

You can start the service by typing `service nginx start`

----------
### **HHVM**
```
wget -O - http://dl.hhvm.com/conf/hhvm.gpg.key | sudo apt-key add -
echo deb http://dl.hhvm.com/ubuntu trusty main | tee /etc/apt/sources.list.d/hhvm.list
sudo apt-get update && apt-get install hhvm -y
sudo /usr/share/hhvm/install_fastcgi.sh
```
*NOTE: `install_fastcgi.sh` can sometimes be unreliable for a number of reasons, resulting in an error. If this happens, simply add `include hhvm.conf;` to 'yourdomain.com.conf'. Our `yourdomain.com.conf` and `default.conf` already reflect that step.*
```
sudo service hhvm restart
sudo service nginx restart
```
##### **Setting HHVM to Startup** 
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
```
sudo nano /etc/nginx/hhvm.conf
```

replace `fastcgi_pass   127.0.0.1:9000;` with	`fastcgi_pass unix:/var/run/hhvm/hhvm.sock;`

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
If you're following our config entirely, you'll want to move the `nginx.conf`, `fastcgicache.conf`, `wpsecurity.conf`, `filerules.conf`, and `hhvm.conf` files from this GitHub into `/etc/nginx/`. You'll also want to move the `default.conf` and `yourdomain.com.conf` files into `/etc/nginx/conf.d/`. Then restart HHVM and Nginx.
```
sudo service nginx restart && sudo service hhvm restart
```

----------
### **MariaDB 10** 
We're using the latest version of MariaDB instead of MySQL, as the performance is great with WordPress.
##### **Add MariaDB Repo** 
```
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
sudo add-apt-repository 'deb http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.0/ubuntu trusty main'
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
```
sudo mysql -v -u root -p
```
You can exit MariaDB by typing `exit`

### **phpMyAdmin** 
##### **Add phpMyAdmin Repo**
```
sudo nano /etc/apt/sources.list.d/phpMyAdmin.list
```
Paste the 2 lines below, then save.
```
deb http://ppa.launchpad.net/nijel/phpmyadmin/ubuntu trusty main 
deb-src http://ppa.launchpad.net/nijel/phpmyadmin/ubuntu trusty main 
```
##### **Installing phpMyAdmin** 
We had some silly issue preventing the installation during one of our installs. If you run into this, it can be bypassed entirely by forcing the installation. We included that command.
During the installation, just hit `tab` and `enter` when the script prompts you to choose apache or lighttpd. We're not using either, but it'll probably install apache and php5 anyway. So we'll need to disable both from starting when the server restarts.
```
sudo apt-get install phpmyadmin --force-yes
sudo update-rc.d -f apache2 remove
sudo update-rc.d -f php5 remove
```
Here we're going to make a symbolic link from the phpMyAdmin folder to our default domain's public facing folder. Using this setup, phpMyAdmin will only be viewable by vising your server's IP address directly. 
```
sudo ln -s /usr/share/phpmyadmin /var/www/html
```
There's currently a problem with HHVM connecting to the version of phpMyAdmin we installed. To fix this we've got to make a quick edit.
```
sudo nano /etc/phpmyadmin/config-db.php
```
change `$dbport` from `'';` to `'3306';`
Point your browser to http://ipa.ddr.ess/phpmyadmin

----------
### **WordPress** 
##### **Creating a MySQL Database** 
We're going to create the database by command linr because we're cool. You can also do this directly though phpMyAdmin, if you're not as cool. Replace the `database`, `user`, and `password` variables in the code below.
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
----------
### **Self-Signed SSL Certificate** 
Here we're going to generate a self-signed SSL certificate. Since we're using CloudFlare anyway, we're going to use a *FREE* SSL certificate through them. You'll need to set CloudFlare's SSL certificate status to `Full` for this to work.
```
sudo openssl req -x509 -nodes -days 365000 -newkey rsa:2048 -keyout /etc/nginx/ssl/yourdomain.com.key -out /etc/nginx/ssl/yourdomain.com.crt
cd /etc/nginx/ssl
openssl dhparam -out yourdomain.pem 2048
```
----------

### **FastCGI Cache Conditional Purging** 

You'll want a way to purge the cache when you make changes to the site, such as editing a post, changing a menu, or deleting a comment.

#### **Nginx Cache WordPress Plugin**
We like Till Krüss' Nginx Cache plugin because it's simple and works regardless what Nginx modules you have installed. 
At the WordPress Dashboard under `Tools` then `Nginx`,  add the FastCGI cache location `/var/run/nginx-cache` and make sure the box to automatically flush cache when content changes. 
Download: https://wordpress.org/plugins/nginx-cache/
----------

### **Checking FastCGI Cache** 
It's always a good idea to make sure that what you think is working is in fact actually working. Since we don't want to serve cached versions of every page on the site, inside `hhvm.conf` we've added a list of pages and cookies that we want to avoid caching. To help shed light on things a bit, we've added the line `add_header X-Cached $upstream_cache_status;` inside `/etc/nginx/hhvm.conf`. This will tell us with certainty whether or not the page being served is the cached version. 

We can check the status of any page by viewing the headers that are sent along when you visit it. To do this, you can use a variety of methods. You can use the `CURL` command inside your terminal by typing `curl -v https://yourdomain.com`. Plugins exist for Mozilla FireFox and Google chrome that will make things a bit easier, we prefer Live HTTP Headers for Google Chrome https://chrome.google.com/webstore/detail/live-http-headers/iaiioopjkcekapmldfgbebdclcnpgnlo?utm_source=chrome-app-launcher-info-dialog. Finally, you can always just let another site do the hard work for you, like http://web-sniffer.net/.

You'll encounter 4 different messages based on the cache type. `X-Cached: HIT`, `X-Cached: MISS`, `X-Cached: EXPIRED`, or `X-Cached: BYPASS`. 

######X-Cached: HIT
You're being served a cached version of the page.

######X-Cached: MISS 
The server did not have a cached copy of that page, so you're being fed a live version instead. Initially all pages will show as `X-Cached: MISS`. Once they've been visisted, Nginx will store a copy of that code for future visitors. You can set the number of times a page must be visisted before it's cached by altering the `fastcgi_cache_min_uses` inside `fastcgicache.conf`.

######X-Cached: EXPIRED 
The version that was stored on the server is too old, and you're seeing a live version instead. You can set the amount of time a cached copy is valid by changing the various `fastcgi_cache_valid` variables inside `fastcgicache.conf`.

######X-Cached: BYPASS 
We've told Nginx skip caching a page if it matches a set of criteria. For example, we don't want to cache any page beginning with `WP-`, or any page visisted by a logged in user or recent commenter. You can add to this list inside `hhvm.conf`. Depending on the plugins you're running, there may be additional things you'll want to set to avoid being cached. If you're running WooCommerce or another complicated plugin that might display sensitive data to visitors, read below.

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
