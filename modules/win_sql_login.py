#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = r'''
---
module: win_sql_login
short_description: Updates Windows or SQL Logins on a Windows SQL Server
description:
- Add or remove Windows or SQL Logins from Windows SQL Server
- Update an existing Logins Server Roles or defaults
options:
  state:
    description:
    - Set to C(present) to ensure login exists with the roles specified present.
    - Set to C(pure) to ensure login exists with only the roles specified.
    - Set to C(absent) to ensure login does not exist.
    type: str
    choices: [ absent, present, pure ]
  windows_login:
    description:
    - Windows Login to create
    type: str
  sql_login:
    description:
    - SQL Login to create
    type: str
  password:
    description:
    - Password to set with SQL Login
    type: str
  server_roles:
    description:
    - Server roles
    type: list
  default_database:
    description:
    - Default database for the login
    type: str
  default_language:
    description:
    - Default language for the login
    type: str
notes:
- The windows_login can be an existing Windows Domain user or a group 
  while the sql_login will be a new SQL User which requires a password. 
- Logins need to be mapped to a Database with the the win_sql_user module. 
seealso:
- module: win_sql_user
author:
- Thomas Stalknecht
'''

EXAMPLES = r'''
- name: Create new Windows Login
  win_sql_login:
    state: present
    windows_login: DOMAIN\\User
- name: Create new SQL Login
  win_sql_login:
    state: present
    sql_login: SQLUser
    password: SQLPassword
- name: Update existing Login with new roles
  win_sql_login:
    state: present
    windows_login: DOMAIN\\Group
    server_roles:
      - processadmin
      - dbcreator
- name: Update existing Login to have only specific roles
  win_sql_login:
    state: pure
    windows_login: DOMAIN\\Group
    server_roles:
      - sysadmin
- name: Remove a specific Login
  win_sql_login:
    state: absent
    windows_login: DOMAIN\\User
'''

RETURN = r'''
before_value:
  description: 
  returned: always
  type: str
  sample: 
value:
  description: 
  returned: always
  type: str
  sample: 
'''
