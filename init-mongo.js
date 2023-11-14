db.createUser({
  user: 'admin',
  pwd: '<changepasswordhere>',
  roles: [
    {
      role: 'readWrite',
      db: 'registrator',
    },
  ],
});