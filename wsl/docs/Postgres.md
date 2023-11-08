# Install and use Postgres in WSL

Tài liệu này hướng dẫn việc cài đặt các thư viện, công cụ, tiện ích và cũng như môi trường cho việc biên dịch source code khi triển khai hệ thống trên môi trường WSL2

## 1. Install Postgres
To install Postgres and run it in WSL, all you have to do is the following:

Open your WSL terminal
Update your Ubuntu packages: 
```bash
sudo apt update
```
Once the packages have updated, install PostgreSQL (and the -contrib package which has some helpful utilities) with: 
```bash
sudo apt install -y postgresql postgresql-contrib
```
Confirm installation and get the version number: 
```bash
psql --version
```

## 2. Postgres Commands
The default admin user, postgres, needs a password assigned in order to connect to a database. To set a password:

Enter the command: 
```bash
sudo passwd postgres
# You will get a prompt to enter your new password. Close and reopen your terminal.
# p@stGres2023
```
You can check running status using:
```bash
# note: 12 is postgres version
sudo pg_ctlcluster 12 main status
```

You can check start posgres using:
```bash
# note: 12 is postgres version
sudo pg_ctlcluster 12 main start
```

You can access psql directly using
```bash
sudo -u postgres psql
# You should see your prompt change to:
postgres=#
```

You can create a database using
```bash
su - postgres
createdb mydb
psql mydb
```

To create tables in a database from a file, use the following command:
```bash
psql -U postgres -q mydb < <file-path/file.sql>
```

Useful commands:
* \l lists all databases. Works from any database.
* \dt lists all tables in the current database.
* \c <db name> switch to a different database

```bash
psql mydb
# lists all databases. Works from any database.
mydb=# \l
#  lists all tables in the current database.
mydb=# \dt
# switch to a different database
mydb=# \c <db name>
```


## 3. Links
[1. Install and use Postgres in WSL](https://dev.to/sfpear/install-and-use-postgres-in-wsl-423d)