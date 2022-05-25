-- Connect to MySQL
mysql -u <username> -h <server ip or name> -P <port> -p

-- Close Safe Update Mode
SET SQL_SAFE_UPDATES = 0;

-- Open Safe Update Mode
SET SQL_SAFE_UPDATES = 1;

--remove password validate
mysql> uninstall plugin validate_password;

-- Allow Remote Connection
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'password' WITH GRANT OPTION;
flush privileges;

    sudo mysql -u root

    Check your accounts present in your db

    SELECT User,Host FROM mysql.user;
    +------------------+-----------+
    | User             | Host      |
    +------------------+-----------+
    | admin            | localhost |
    | debian-sys-maint | localhost |
    | magento_user     | localhost |
    | mysql.sys        | localhost |
    | root             | localhost |

    Delete current root@localhost account

    mysql> DROP USER 'root'@'localhost';
    Query OK, 0 rows affected (0,00 sec)

    Recreate your user

    mysql> CREATE USER 'root'@'%' IDENTIFIED BY '';
    Query OK, 0 rows affected (0,00 sec)

    Give permissions to your user (don't forget to flush privileges)

    mysql> GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
    Query OK, 0 rows affected (0,00 sec)

    mysql> FLUSH PRIVILEGES;
    Query OK, 0 rows affected (0,01 sec)

    Exit MySQL and try to reconnect without sudo.
