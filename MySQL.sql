-- Close Safe Update Mode
SET SQL_SAFE_UPDATES = 0;

-- Open Safe Update Mode
SET SQL_SAFE_UPDATES = 1;

-- Allow Remote Connection
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'password' WITH GRANT OPTION;
flush privileges;
