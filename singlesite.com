server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    # Server name to listen for
    server_name example.com;

    ##
    # SSL
    ##

	ssl_certificate /var/www/html/example/ssl/ssl-bundle.crt;
	ssl_certificate_key /var/www/html/example/ssl/example.key;

    ##
    # Logging
    ##

    # Overrides logs defined in nginx.conf, allows per site logs.
	access_log /var/www/html/example/logs/access.log;
	error_log /var/www/html/example/logs/error.log;

    ##
    # Site Files
    ##

    root /var/www/html/example/public/;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    ##
    # Exclusions
    ##

    # Deny all attempts to access hidden files such as .htaccess, .htpasswd, .DS_Store (Mac).
    # Keep logging the requests to parse later (or to pass to firewall utilities such as fail2ban)
    location ~ /\. {
        deny all;
    }

    #allow access to .well-known folder (necessary for certbot/letsencrypt)
    location ^~ /.well-known/ {
    allow all;
    }

    # Deny access to any files with a .php extension in the uploads directory
    # Works in sub-directory installs and also in multisite network
    # Keep logging the requests to parse later (or to pass to firewall utilities such as fail2ban)
    location ~* /(?:uploads|files)/.*\.php$ {
        deny all;
    }

    ##
    # PHP
    ##

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
    }

    ##
    # Wordpress Specific Items
    ##

    # Rewrites for Yoast SEO XML Sitemap
    rewrite ^/sitemap_index.xml$ /index.php?sitemap=1 last;
    rewrite ^/([^/]+?)-sitemap([0-9]+)?.xml$ /index.php?sitemap=$1&sitemap_n=$2 last;

    ##
    # Cache Static Files
    ##

    # Don't cache appcache, document html and data.
    location ~* \.(?:manifest|appcache|html?|xml|json)$ {
        add_header Cache-Control "max-age=0";
    }

    # Cache RSS and Atom feeds.
    location ~* \.(?:rss|atom)$ {
        add_header Cache-Control "max-age=3600";
    }

    # Caches images, icons, video, audio, HTC, etc.
    location ~* \.(?:jpg|jpeg|gif|png|ico|cur|gz|svg|mp4|ogg|ogv|webm|htc)$ {
        add_header Cache-Control "max-age=31536000";
        access_log off;
    }

    # Cache svgz files, but don't compress them.
    location ~* \.svgz$ {
        add_header Cache-Control "max-age=31536000";
        access_log off;
        gzip off;
    }

    # Cache CSS and JavaScript.
    location ~* \.(?:css|js)$ {
        add_header Cache-Control "max-age=31536000";
        access_log off;
    }

    # Cache WebFonts.
    location ~* \.(?:ttf|ttc|otf|eot|woff|woff2)$ {
        add_header Cache-Control "max-age=31536000";
        access_log off;
    }

    # Don't record access/error logs for robots.txt.
    location = /robots.txt {
        access_log off;
        log_not_found off;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name www.example.com;

    # Paths to certificate files.
	ssl_certificate /var/www/html/example/ssl/ssl-bundle.crt;
	ssl_certificate_key /var/www/html/example/ssl/example.key;

    return 301 https://example.com$request_uri;
}

server {
    listen 80;
    listen [::]:80;

    server_name example.com www.example.com;

    return 301 https://example.com$request_uri;
}