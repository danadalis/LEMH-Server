## **LEMH on Ubuntu 14.04 Trusty**
## **Nginx, HHVM, MariaDB 10, FastCGI Cache, and CloudFlare SSL)**
### **Basics**
##### **Initial setup**
```
passwd
apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y
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
We'll be using the nginx-extras found on the Launchpad Mainline PPA because this comes pre-installed with the More Headers and FastCGI purge modules. If you need different modules you'll to compile Nginx from source instead. 

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
Here we're going to ensure that the right folders are in place for our config. In addition, since we might be hosting multiple domains on this server, we've told our `yourdomain.com.conf` files to log to the standard `/var/log` directory but to a dedicated folder like Nginx or HHVM have.
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
*NOTE: `install_fastcgi.sh` can be flaky sometimes and may not work. If it gives you an error, simply add `include hhvm.conf;` to 'yourdomain.com.conf'. Our config already reflects that step.*
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
Let's set some quick variables so that HHVM has good timeouts and filesize limits for WordPress. Feel free to adjust these based on your needs
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
The latest version of HHVM now supports the `phpinfo` command, so you'll be able to get a lot of useful info about your installation. Here we're going to write a very basic php file that will give us this information. We're going to send it straight to your servers default folder, which will be `/var/www/html`. By contrast, domains will be using `/var/www/yourdomain.com/html`.
```
echo "<?php phpinfo(); ?>" > /var/www/html/phpinfo.php
```
Point your browser to http://ipa.ddr.ess/phpinfo.php.

----------
#### **.conf Files** 
If you're following our config entirely, you'll want to move the `nginx.conf`, `fastcgicache.conf`, `wpsecurity.conf`, `filerules.conf`, and `hhvm.conf` files from this GitHub into the `/etc/nginx/` directory. You'll also want to move the `default.com.conf` and `yourdomain.com.conf` files into `/etc/nginx/conf.d`. Then restart HHVM and Nginx.
```
sudo service nginx restart
sudo service hhvm restart
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
sudo apt-get update -y && apt-get install mariadb-server -y
```
Make sure that MariaDB has upgraded to the latest files by running this again.
```
sudo apt-get update -y && sudo apt-get upgrade -y && sudo apt-get dist-upgrade -y
```
##### **Securing MariaDB** 
MariaDB includes some test users and databases that we don't want to be using in a live production environment. Now that MariaDB is installed, run this command. Since we've already set the admin password, we can say No to the first option. You'll want to say Yes to the rest of the questions.
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
##### **Installing phpMyAdmin** 
This part is pretty simple, since the repos we're using already will give us phpMyAdmin. During the installation, just hit `tab` and `enter` when the script prompts you to choose apache or lighttpd. We're not using either, but it'll probably install apache anyway. So we'll need to disable it from starting up when we restart.
```
sudo apt-get install phpmyadmin -y
sudo update-rc.d -f apache2 remove
sudo update-rc.d -f php5 remove
```
Here we're going to make a symbolic link from the phpMyAdmin folder to our default domain's public facing folder. Using this setup, phpMyAdmin will only be viewable by vising your server's IP address directly. 
```
sudo ln -s /usr/share/phpmyadmin /var/www/html
```
There's currently a problem with HHVM connecting to the version of phpMyAdmin we installed. To fix this we've got to make a quick edit.
```
sudo nano /usr/share/phpmyadmin/libraries/dbi/mysqli.dbi.lib.php
```
Paste this code towards the top, right above the line `require_once './libraries/logging.lib.php';`
```
$GLOBALS['cfg']['Server']['port'] = 3306;
```
Point your browser to http://ipa.ddr.ess/phpmyadmin.

----------
### **WordPress** 
##### **Creating a MySQL Database** 
We're going to create the database by command because we're cool. You can also do this directly though phpMyAdmin. Replase the `database`, `user`, and `password` entries in the code below.
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
Here we're going to generate a self-signed SSL certificate. Since we're using CloudFlare anyway, we're going to use an SSL certificate through them. You'll need to set CloudFlare's SSL certificate status to `Full`.
```
sudo openssl req -x509 -nodes -days 365000 -newkey rsa:2048 -keyout /etc/nginx/ssl/yourdomain.com.key -out /etc/nginx/ssl/yourdomain.com.crt
cd /etc/nginx/ssl
openssl dhparam -out yourdomain.pem 2048
```
----------											
### **Optional Stuff** 
##### **HHVM and Nginx Timeouts** 
If you're doing an import into WordPress, or something else that will be processing for along time, you'll want to increase the timeout variables  for HHVM and Nginx. Change these temporarily.
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
JetPack is widely used in WordPress installations for good reason. The Photon module doesn't always play nice with WordPress installations that force SSL all the time, resulting in pictures that don't get served by Photon's CDN. A simple code addition tells Photon to stop rejecting images that are served via https.

Edit your theme's `functions.php`. Add this code towards the top somewhere nice. If you're using a theme that updates frequently you'll want to add a child theme, or you'll need to do this edit every time you update.
```
sudo nano /var/www/yourdomain.com/html/wp-content/themes/your-theme-folder/functions.php
```
Add this code towards the top somewhere nice.
```
add_filter( 'jetpack_photon_reject_https', '__return_false' );
```
### **Done!** 
