server {
	# Ports to listen on, uncomment one.
	listen 443 ssl http2;
	listen [::]:443 ssl http2;

	# Server name to listen for
	server_name example.com;

	# Path to document root
	root /var/www/html/example/public;

	# Paths to certificate files.
	ssl_certificate /var/www/html/example/ssl/ssl-bundle.crt;
	ssl_certificate_key /var/www/html/example/ssl/urbanrealtyllc.key;

	# File to be used as index
	index index.php;

	# Overrides logs defined in nginx.conf, allows per site logs.
	access_log /var/www/html/example/logs/access.log;
	error_log /var/www/html/example/logs/error.log;

	# Default server block rules
	include global/server/defaults.conf;

	# SSL rules
	include global/server/ssl.conf;

	location / {
		try_files $uri $uri/ /index.php?$args;
	}

	location ~ \.php$ {
		try_files $uri =404;
		include global/fastcgi-params.conf;

		# Use the php pool defined in the upstream variable.
		# See global/php-pool.conf for definition.
		fastcgi_pass   $upstream;
	}

	# Rewrites for Yoast SEO XML Sitemap
    rewrite ^/sitemap_index.xml$ /index.php?sitemap=1 last;
    rewrite ^/([^/]+?)-sitemap([0-9]+)?.xml$ /index.php?sitemap=$1&sitemap_n=$2 last;

	# Rewrite robots.txt
	rewrite ^/robots.txt$ /index.php last;

	# Uncomment if using the fastcgi_cache_purge module and Nginx Helper plugin (https://wordpress.org/plugins/nginx-helper/)
	location ~ /purge(/.*) {
		fastcgi_cache_purge urbanrealtyllc "$scheme$request_method$host$1";
	}
}

# Redirect http to https
server {
	listen 80;
	listen [::]:80;
	server_name example.com www.example.com;

	return 301 https://example.com$request_uri;
}

# Redirect www to non-www
server {
	listen 443;
	listen [::]:443;
	server_name www.example.com;

	return 301 https://example.com$request_uri;
}

