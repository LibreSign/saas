CREATE DATABASE wordpress;
CREATE DATABASE nextcloud;
CREATE USER 'nextcloud'@'%' IDENTIFIED BY 'nextcloud';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'%';
