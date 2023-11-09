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

## 2. Postgres Tutorials

### 2.1 Creating a Database
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
# /usr/local/pgsql/bin/createdb mydb
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
* \dus list users

```bash
psql mydb
# lists all databases. Works from any database.
mydb=# \l
#  lists all tables in the current database.
mydb=# \dt
# switch to a different database
mydb=# \c <db name>
```

### 2.2 Database Roles

#### [2.2.1 Database Roles](https://www.postgresql.org/docs/current/database-roles.html)
PostgreSQL manages database access permissions using the concept of roles. ***A role can be thought of as either a database user, or a group of database users***, depending on how the role is set up. Roles can own database objects (for example, tables and functions) and can assign privileges on those objects to other roles to control who has access to which objects. Furthermore, it is possible to grant membership in a role to another role, thus allowing the member role to use privileges assigned to another role.

Database roles are conceptually completely separate from operating system users. In practice it might be convenient to maintain a correspondence, but this is not required. Database roles are global across a database cluster installation (and not per individual database). To create a role use the CREATE ROLE SQL command:
```bash
psql mydb
mydb=# CREATE ROLE myrole;
```

name follows the rules for SQL identifiers: either unadorned without special characters, or double-quoted. (In practice, you will usually want to add additional options, such as LOGIN, to the command. More details appear below.) To remove an existing role, use the analogous DROP ROLE command:

```bash
psql mydb
mydb=# DROP ROLE myrole;
```
For convenience, the programs createuser and dropuser are provided as wrappers around these SQL commands that can be called from the shell command line:
```bash
createuser myuser
dropuser myuser
```
To determine the set of existing roles, examine the pg_roles system catalog, for example:
```bash
psql mydb
mydb=# SELECT rolname, rolcanlogin FROM pg_roles;
```

or to see just those capable of logging in:
```bash
psql mydb
mydb=# SELECT rolname FROM pg_roles WHERE rolcanlogin;
```
The psql program's \du meta-command is also useful for listing the existing roles.

In order to bootstrap the database system, a freshly initialized system always contains one predefined login-capable role. This role is always a “superuser”, and it will have the same name as the operating system user that initialized the database cluster with initdb unless a different name is specified. This role is often named **postgres**. In order to create more roles you first have to connect as this initial role.

#### [2.2.2 Role Attributes](https://www.postgresql.org/docs/current/role-attributes.html)
A database role can have a number of attributes that define its privileges and interact with the client authentication system.

* login privilege
  
    Only roles that have the LOGIN attribute can be used as the initial role name for a database connection. A role with the LOGIN attribute can be considered the same as a “database user”. To create a role with login privilege, use either:
    ```bash
    CREATE ROLE name LOGIN;
    CREATE USER name;
    ```
* password
  
  A password is only significant if the client authentication method requires the user to supply a password when connecting to the database. The password and md5 authentication methods make use of passwords. Database passwords are separate from operating system passwords. Specify a password upon role creation with 
  ```bash
  CREATE ROLE name PASSWORD 'string'.
  ```
* connection limit
  
  Connection limit can specify how many concurrent connections a role can make. -1 (the default) means no limit. Specify connection limit upon role creation with
  ```bash
  CREATE ROLE name CONNECTION LIMIT 'integer'.
  ```

A role's attributes can be modified after creation with ALTER ROLE. See the reference pages for the CREATE ROLE and ALTER ROLE commands for details.

A role can also have role-specific defaults for many of the run-time configuration settings described in Chapter 20. For example, if for some reason you want to disable index scans (hint: not a good idea) anytime you connect, you can use:

```bash
ALTER ROLE myname SET enable_indexscan TO off;
 ```

#### [2.2.3 Role Membership](https://www.postgresql.org/docs/current/role-membership.html)

It is frequently convenient to group users together to ease management of privileges: that way, privileges can be granted to, or revoked from, a group as a whole. In PostgreSQL this is done by creating a role that represents the group, and then granting membership in the group role to individual user roles.

To set up a group role, first create the role:
```bash
CREATE ROLE name;
```

Typically **a role being used as a group would not have the LOGIN attribute**, though you can set it if you wish.

Once the group role exists, you can add and remove members using the GRANT and REVOKE commands:
```bash
GRANT group_role TO role1, ... ;
REVOKE group_role FROM role1, ... ;
```

## 3. Python Environment

```bash
sudo apt install postgresql postgresql-contrib  

sudo apt install -y libpq-dev python3-dev python3-pip python3-psycopg2
pip3 install psycopg2
pip3 install psycopg2-binary
```


##  Links
[1. Install and use Postgres in WSL](https://dev.to/sfpear/install-and-use-postgres-in-wsl-423d)