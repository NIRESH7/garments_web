import dns from 'dns';
dns.setDefaultResultOrder('ipv4first');
dns.resolveSrv('_mongodb._tcp.cluster0.ffresp2.mongodb.net', (err, addresses) => {
  if (err) {
    console.error('DNS Srv Resolve Error:', err);
  } else {
    console.log('Addresses:', addresses);
  }
});
