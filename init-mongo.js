db = db.getSiblingDB('registrator');
db.createUser({
  user: 'admin',
  pwd: 'INTELLECT123INTELLECT123INTELLECT123',
  roles: [
    {
      role: 'readWrite',
      db: 'registrator',
    },
  ],
});
db = db.getSiblingDB('platform');
db.createUser({
  user: 'admin',
  pwd: 'INTELLECT123INTELLECT123INTELLECT123PlaTFoRM',
  roles: [
    {
      role: 'readWrite',
      db: 'platform',
    },
  ],
});

