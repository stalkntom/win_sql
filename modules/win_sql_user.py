#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = r'''
---
module: win_sql_user
short_description: Updates Users on a Windows SQL Server Database
description:
- Add or remove Users from Windows SQL Server Databases
- Update an existing Users Database Roles or defaults
options:
  state:
    description:
    - Set to C(present) to ensure user exists on the database with the specified database roles.
    - Set to C(pure) to ensure login exists with only the roles specified.
    - Set to C(absent) to ensure login does not exist.
    type: str
    choices: [ absent, present, pure ]
  database:
    description:
    - Database for user
    type: str
  user:
    description:
    - User of Database
    type: str
  login:
    description:
    - Login to map to User
    type: str
  database_roles:
    description:
    - Database roles to assign user
    type: list
  default_schema:
    description:
    - Default schema of the user
    type: str
notes:
- 
seealso:
- module: win_sql_login
author:
- Thomas Stalknecht
'''

EXAMPLES = r'''
- name: Map login to user
  win_sql_user:
    state: present
    database: Database
    user: DOMAIN\\Group
    login: DOMAIN\\Group
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
