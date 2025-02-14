package Vyatta::L2TPConfig;

use strict;
use lib "/opt/vyatta/share/perl5";
use Vyatta::Config;
use Vyatta::Misc;
use NetAddr::IP;

my $cfg_delim_begin = '### VyOS L2TP VPN Begin ###';
my $cfg_delim_end = '### VyOS L2TP VPN End ###';

my $CA_CERT_PATH = '/etc/ipsec.d/cacerts';
my $CRL_PATH = '/etc/ipsec.d/crls';
my $SERVER_CERT_PATH = '/etc/ipsec.d/certs';
my $SERVER_KEY_PATH = '/etc/ipsec.d/private';

my %fields = (
  _mode             => undef,
  _psk              => undef,
  _x509_cacert      => undef,
  _x509_crl         => undef,
  _x509_s_cert      => undef,
  _x509_s_key       => undef,
  _x509_s_pass      => undef,
  _out_addr         => undef,
  _dhcp_if          => undef,
  _out_nexthop      => undef,
  _client_ip_start  => undef,
  _client_ip_stop   => undef,
  _auth_mode        => undef,
  _radius_source    => undef,
  _mtu              => undef,
  _idle             => undef,
  _ike_lifetime     => undef,
  _esplifetime      => undef,
  _auth_require     => undef,
  _auth_local       => [],
  _auth_radius      => [],
  _auth_radius_keys => [],
  _dns              => [],
  _wins             => [],
  _is_empty         => 1,
);

sub new {
  my $that = shift;
  my $class = ref ($that) || $that;
  my $self = {
    %fields,
  };

  bless $self, $class;
  return $self;
}

sub setup {
  my ( $self ) = @_;
  my $config = new Vyatta::Config;

  $config->setLevel('vpn l2tp remote-access');
  my @nodes = $config->listNodes();
  if (scalar(@nodes) <= 0) {
    $self->{_is_empty} = 1;
    return 0;
  } else {
    $self->{_is_empty} = 0;
  }
  $self->{_dhcp_if} = $config->returnValue('dhcp-interface');
  $self->{_mode} = $config->returnValue('ipsec-settings authentication mode');
  $self->{_ike_lifetime} = $config->returnValue('ipsec-settings ike-lifetime');
  $self->{_esplifetime} = $config->returnValue('ipsec-settings lifetime');
  $self->{_psk}
    = $config->returnValue('ipsec-settings authentication pre-shared-secret');
  my $pfx = 'ipsec-settings authentication x509';
  $self->{_x509_cacert} = $config->returnValue("$pfx ca-cert-file");
  $self->{_x509_crl} = $config->returnValue("$pfx crl-file");
  $self->{_x509_s_cert} = $config->returnValue("$pfx server-cert-file");
  $self->{_x509_s_key} = $config->returnValue("$pfx server-key-file");
  $self->{_x509_s_pass} = $config->returnValue("$pfx server-key-password");

  $self->{_out_addr} = $config->returnValue('outside-address');
  $self->{_out_nexthop} = $config->returnValue('outside-nexthop');
  $self->{_client_ip_start} = $config->returnValue('client-ip-pool start');
  $self->{_client_ip_stop} = $config->returnValue('client-ip-pool stop');
  $self->{_auth_mode} = $config->returnValue('authentication mode');
  $self->{_auth_require} = $config->returnValue('authentication require');
  $self->{_mtu} = $config->returnValue('mtu');
  $self->{_idle} = $config->returnValue('idle');

  my @users = $config->listNodes('authentication local-users username');
  foreach my $user (@users) {
    my $plvl = "authentication local-users username $user password";
    my $pass = $config->returnValue("$plvl");
    my $dlvl = "authentication local-users username $user disable";
    my $disable = 'enable';
    $disable = 'disable' if $config->exists("$dlvl");
    my $ilvl = "authentication local-users username $user static-ip";
    my $ip = $config->returnValue("$ilvl");
    $ip = 'none' if (!defined($ip));
    $self->{_auth_local} = [ @{$self->{_auth_local}}, $user, $pass, $disable, $ip ];
  }

  my @rservers = $config->listNodes('authentication radius server');
  foreach my $rserver (@rservers) {
    my $key = $config->returnValue(
                        "authentication radius server $rserver key");
    $self->{_auth_radius} = [ @{$self->{_auth_radius}}, $rserver ];
    if (defined($key)) {
      $self->{_auth_radius_keys} = [ @{$self->{_auth_radius_keys}}, $key ];
    }
    # later we will check if the two lists have the same length
  }

  my $tmp = $config->returnValue('dns-servers server-1');
  if (defined($tmp)) {
    $self->{_dns} = [ @{$self->{_dns}}, $tmp ];
  }
  $tmp = $config->returnValue('dns-servers server-2');
  if (defined($tmp)) {
    $self->{_dns} = [ @{$self->{_dns}}, $tmp ];
  }

  $tmp = $config->returnValue('wins-servers server-1');
  if (defined($tmp)) {
    $self->{_wins} = [ @{$self->{_wins}}, $tmp ];
  }
  $tmp = $config->returnValue('wins-servers server-2');
  if (defined($tmp)) {
    $self->{_wins} = [ @{$self->{_wins}}, $tmp ];
  }

  $tmp = $config->returnValue('authentication radius source-address');
  if (defined($tmp)) {
    $self->{_radius_source} = $tmp;
  } else {
    $self->{_radius_source} = "*";
  }

  return 0;
}

sub setupOrig {
  my ( $self ) = @_;
  my $config = new Vyatta::Config;

  $config->setLevel('vpn l2tp remote-access');
  my @nodes = $config->listOrigNodes();
  if (scalar(@nodes) <= 0) {
    $self->{_is_empty} = 1;
    return 0;
  } else {
    $self->{_is_empty} = 0;
  }
  $self->{_dhcp_if} = $config->returnOrigValue('dhcp-interface');
  $self->{_mode} = $config->returnOrigValue(
                            'ipsec-settings authentication mode');
  $self->{_ike_lifetime} = $config->returnOrigValue(
                            'ipsec-settings ike-lifetime');
  $self->{_esplifetime} = $config->returnOrigValue(
                            'ipsec-settings lifetime');
  $self->{_psk} = $config->returnOrigValue(
                            'ipsec-settings authentication pre-shared-secret');
  my $pfx = 'ipsec-settings authentication x509';
  $self->{_x509_cacert} = $config->returnOrigValue("$pfx ca-cert-file");
  $self->{_x509_crl} = $config->returnOrigValue("$pfx crl-file");
  $self->{_x509_s_cert} = $config->returnOrigValue("$pfx server-cert-file");
  $self->{_x509_s_key} = $config->returnOrigValue("$pfx server-key-file");
  $self->{_x509_s_pass} = $config->returnOrigValue("$pfx server-key-password");

  $self->{_out_addr} = $config->returnOrigValue('outside-address');
  $self->{_out_nexthop} = $config->returnOrigValue('outside-nexthop');
  $self->{_client_ip_start} = $config->returnOrigValue('client-ip-pool start');
  $self->{_client_ip_stop} = $config->returnOrigValue('client-ip-pool stop');
  $self->{_auth_mode} = $config->returnOrigValue('authentication mode');
  $self->{_radius_source} = $config->returnValue('authentication radius source-address');
  $self->{_auth_require} = $config->returnValue('authentication require');
  $self->{_mtu} = $config->returnOrigValue('mtu');
  $self->{_idle} = $config->returnOrigValue('idle');

  my @users = $config->listOrigNodes('authentication local-users username');
  foreach my $user (@users) {
    my $plvl = "authentication local-users username $user password";
    my $pass = $config->returnOrigValue("$plvl");
    my $dlvl = "authentication local-users username $user disable";
    my $disable = 'enable';
    $disable = 'disable' if $config->existsOrig("$dlvl");
    my $ilvl = "authentication local-users username $user static-ip";
    my $ip = $config->returnOrigValue("$ilvl");
    $ip = 'none' if (!defined($ip));
    $self->{_auth_local} = [ @{$self->{_auth_local}}, $user, $pass, $disable, $ip ];
  }

  my @rservers = $config->listOrigNodes('authentication radius server');
  foreach my $rserver (@rservers) {
    my $key = $config->returnOrigValue(
                        "authentication radius server $rserver key");
    $self->{_auth_radius} = [ @{$self->{_auth_radius}}, $rserver ];
    if (defined($key)) {
      $self->{_auth_radius_keys} = [ @{$self->{_auth_radius_keys}}, $key ];
    }
    # later we will check if the two lists have the same length
  }

  my $tmp = $config->returnOrigValue('dns-servers server-1');
  if (defined($tmp)) {
    $self->{_dns} = [ @{$self->{_dns}}, $tmp ];
  }
  $tmp = $config->returnOrigValue('dns-servers server-2');
  if (defined($tmp)) {
    $self->{_dns} = [ @{$self->{_dns}}, $tmp ];
  }

  $tmp = $config->returnOrigValue('wins-servers server-1');
  if (defined($tmp)) {
    $self->{_wins} = [ @{$self->{_wins}}, $tmp ];
  }
  $tmp = $config->returnOrigValue('wins-servers server-2');
  if (defined($tmp)) {
    $self->{_wins} = [ @{$self->{_wins}}, $tmp ];
  }

  $tmp = $config->returnValue('authentication radius-source-address');
  if (defined($tmp)) {
    $self->{_radius_source} = $tmp;
  } else {
    $self->{_radius_source} = "*";
  }

  return 0;
}

sub listsDiff {
  my @a = @{$_[0]};
  my @b = @{$_[1]};
  return 1 if ((scalar @a) != (scalar @b));
  while (my $a = shift @a) {
    my $b = shift @b;
    return 1 if ($a ne $b);
  }
  return 0;
}

sub globalIPsecChanged {
  my $config = new Vyatta::Config();
  $config->setLevel('vpn');
  # for now, treat it as changed if anything under ipsec changed
  return 1 if ($config->isChanged('ipsec'));
  return 0;
}

sub isDifferentFrom {
  my ($this, $that) = @_;

  return 1 if ($this->{_is_empty} ne $that->{_is_empty});
  return 1 if ($this->{_mode} ne $that->{_mode});
  return 1 if ($this->{_ike_lifetime} ne $that->{_ike_lifetime});
  return 1 if ($this->{_esplifetime} ne $that->{_esplifetime});
  return 1 if ($this->{_psk} ne $that->{_psk});
  return 1 if ($this->{_x509_cacert} ne $that->{_x509_cacert});
  return 1 if ($this->{_x509_crl} ne $that->{_x509_crl});
  return 1 if ($this->{_x509_s_cert} ne $that->{_x509_s_cert});
  return 1 if ($this->{_x509_s_key} ne $that->{_x509_s_key});
  return 1 if ($this->{_x509_s_pass} ne $that->{_x509_s_pass});
  return 1 if ($this->{_out_addr} ne $that->{_out_addr});
  return 1 if ($this->{_dhcp_if} ne $that->{_dhcp_if});
  return 1 if ($this->{_out_nexthop} ne $that->{_out_nexthop});
  return 1 if ($this->{_client_ip_start} ne $that->{_client_ip_start});
  return 1 if ($this->{_client_ip_stop} ne $that->{_client_ip_stop});
  return 1 if ($this->{_auth_mode} ne $that->{_auth_mode});
  return 1 if ($this->{_radius_source} ne $that->{_radius_source});
  return 1 if ($this->{_auth_require} ne $that->{_auth_require});
  return 1 if ($this->{_mtu} ne $that->{_mtu});
  return 1 if ($this->{_idle} ne $that->{_idle});
  return 1 if (listsDiff($this->{_auth_local}, $that->{_auth_local}));
  return 1 if (listsDiff($this->{_auth_radius}, $that->{_auth_radius}));
  return 1 if (listsDiff($this->{_auth_radius_keys},
                         $that->{_auth_radius_keys}));
  return 1 if (listsDiff($this->{_dns}, $that->{_dns}));
  return 1 if (listsDiff($this->{_wins}, $that->{_wins}));
  return 1 if (globalIPsecChanged());

  return 0;
}

sub needsRestart {
  my ($this, $that) = @_;

  return 1 if ($this->{_is_empty} ne $that->{_is_empty});
  return 1 if ($this->{_mode} ne $that->{_mode});
  return 1 if ($this->{_ike_lifetime} ne $that->{_ike_lifetime});
  return 1 if ($this->{_esplifetime} ne $that->{_esplifetime});
  return 1 if ($this->{_psk} ne $that->{_psk});
  return 1 if ($this->{_x509_cacert} ne $that->{_x509_cacert});
  return 1 if ($this->{_x509_crl} ne $that->{_x509_crl});
  return 1 if ($this->{_x509_s_cert} ne $that->{_x509_s_cert});
  return 1 if ($this->{_x509_s_key} ne $that->{_x509_s_key});
  return 1 if ($this->{_x509_s_pass} ne $that->{_x509_s_pass});
  return 1 if ($this->{_out_addr} ne $that->{_out_addr});
  return 1 if ($this->{_dhcp_if} ne $that->{_dhcp_if});
  return 1 if ($this->{_out_nexthop} ne $that->{_out_nexthop});
  return 1 if ($this->{_client_ip_start} ne $that->{_client_ip_start});
  return 1 if ($this->{_client_ip_stop} ne $that->{_client_ip_stop});
  return 1 if ($this->{_mtu} ne $that->{_mtu});
  return 1 if ($this->{_idle} ne $that->{_idle});
  return 1 if (globalIPsecChanged());

  return 0;
}

sub isEmpty {
  my ($self) = @_;
  return $self->{_is_empty};
}

sub setupX509IfNecessary {
  my ($self) = @_;
  return (undef, "IPsec authentication mode not defined")
    if (!defined($self->{_mode}));
  my $mode = $self->{_mode};
  if ($mode eq 'pre-shared-secret') {
    return;
  }

  return "\"ca-cert-file\" must be defined for X.509\n"
    if (!defined($self->{_x509_cacert}));
  return "\"server-cert-file\" must be defined for X.509\n"
    if (!defined($self->{_x509_s_cert}));
  return "\"server-key-file\" must be defined for X.509\n"
    if (!defined($self->{_x509_s_key}));

  return "Invalid ca-cert-file \"$self->{_x509_cacert}\""
    if (! -f $self->{_x509_cacert});
  return "Invalid server-cert-file \"$self->{_x509_s_cert}\""
    if (! -f $self->{_x509_s_cert});
  return "Invalid server-key-file \"$self->{_x509_s_key}\""
    if (! -f $self->{_x509_s_key});

  if (defined($self->{_x509_crl})) {
    return "Invalid crl-file \"$self->{_x509_crl}\""
      if (! -f $self->{_x509_crl});
    system("cp -f $self->{_x509_crl} $CRL_PATH/");
    return "Cannot copy $self->{_x509_crl}" if ($? >> 8);
  }

  # perform more validation of the files

  system("cp -f $self->{_x509_cacert} $CA_CERT_PATH/");
  return "Cannot copy $self->{_x509_cacert}" if ($? >> 8);
  system("cp -f $self->{_x509_s_cert} $SERVER_CERT_PATH/");
  return "Cannot copy $self->{_x509_s_cert}" if ($? >> 8);
  system("cp -f $self->{_x509_s_key} $SERVER_KEY_PATH/");
  return "Cannot copy $self->{_x509_s_key}" if ($? >> 8);

  return;
}

sub get_ipsec_secrets {
  my ($self) = @_;
  return (undef, "IPsec authentication mode not defined")
    if (!defined($self->{_mode}));
  my $mode = $self->{_mode};
  if ($mode eq 'pre-shared-secret') {
    # PSK
    my $key = $self->{_psk};
    my $oaddr = $self->{_out_addr};
    if (defined($self->{_dhcp_if})){
      return  (undef, "The specified interface is not configured for DHCP")
        if (!Vyatta::Misc::is_dhcp_enabled($self->{_dhcp_if},0));
      my $dhcpif = $self->{_dhcp_if};
      $oaddr = get_dhcp_addr($dhcpif);
    }
    return (undef, "IPsec pre-shared secret not defined") if (!defined($key));
    return (undef, "Outside address not defined") if (!defined($oaddr));
    my $str = "$cfg_delim_begin\n";
    $oaddr = "#" if ($oaddr eq '');
    $str .= "$oaddr %any : PSK \"$key\"";
    $str .= " \#dhcp-ra-interface=$self->{_dhcp_if}\#" if (defined($self->{_dhcp_if}));
    $str .= "\n";
    $str .= "$cfg_delim_end\n";
    return ($str, undef);
  } else {
    # X509
    my $key_file = $self->{_x509_s_key};
    my $key_pass = $self->{_x509_s_pass};
    return (undef, "\"server-key-file\" not defined")
      if (!defined($key_file));
    my $pstr = (defined($key_pass) ? " \"$key_pass\"" : '');
    $key_file =~ s/^.*(\/[^\/]+)$/${SERVER_KEY_PATH}$1/;
    my $str =<<EOS;
$cfg_delim_begin
: RSA ${key_file}$pstr
$cfg_delim_end
EOS
    return ($str, undef);
  }
}
sub get_dhcp_addr{
  my ($if) = @_;
  my @dhcp_addr = Vyatta::Misc::getIP($if, 4);
  my $ifaceip = shift(@dhcp_addr);
  @dhcp_addr = split(/\//, $ifaceip);
  $ifaceip = $dhcp_addr[0];
  return ' ' if (!defined($ifaceip));
  return $ifaceip;
}

sub get_ra_conn {
  my ($self, $name) = @_;
  my $oaddr = $self->{_out_addr};
  if (defined($self->{_dhcp_if})){
    return  (undef, "The specified interface is not configured for DHCP")
      if (!Vyatta::Misc::is_dhcp_enabled($self->{_dhcp_if},0));
    my $dhcpif = $self->{_dhcp_if};
    $oaddr = get_dhcp_addr($dhcpif);
  }
  return (undef, "Outside address not defined") if (!defined($oaddr));
  my $onh = $self->{_out_nexthop};
  return (undef, "outside-nexthop cannot be defined with dhcp-interface")
    if (defined($onh) && defined($self->{_dhcp_if}));
  my $onhstr = (defined($onh) ? "  leftnexthop=$onh\n" : "");
  my $auth_str = "authby=secret\n  leftauth=psk\n  rightauth=psk";
  return (undef, "IPsec authentication mode not defined")
    if (!defined($self->{_mode}));
  if ($self->{_mode} eq 'x509') {
    my $server_cert = $self->{_x509_s_cert};
    return (undef, "\"server-cert-file\" not defined")
      if (!defined($server_cert));
    $server_cert =~ s/^.*(\/[^\/]+)$/${SERVER_CERT_PATH}$1/;
    $auth_str =<<EOS
  authby=rsasig
  leftrsasigkey=%cert
  rightrsasigkey=%cert
  rightca=%same
  leftcert=$server_cert
EOS
  }
  my $str =<<EOS;
$cfg_delim_begin
conn $name
  type=transport
  left=$oaddr
  leftsubnet=%dynamic[/1701]
  rightsubnet=%dynamic
  auto=add
  ike=aes256-sha1-modp1024,3des-sha1-modp1024,3des-sha1-modp1024!
  dpddelay=15
  dpdtimeout=45
  dpdaction=clear
  esp=aes256-sha1,3des-sha1!
  rekey=no
  $auth_str
EOS
  if (defined($self->{_ike_lifetime})){
    $str .= "  ikelifetime=$self->{_ike_lifetime}\n";
  } else {
    $str .= "  ikelifetime=3600s\n";
  }
  if (defined($self->{_esplifetime})){
    $str .= "  keylife=$self->{_esplifetime}\n";
  } else {
    $str .= "  keylife=3600s\n";
  }
  $str .= "$cfg_delim_end\n";
  return ($str, undef);
}

sub get_chap_secrets {
  my ($self) = @_;
  return (undef, "Authentication mode must be specified")
    if (!defined($self->{_auth_mode}));
  my @users = @{$self->{_auth_local}};
  print "L2TP warning: Local user authentication not defined\n"
    if ($self->{_auth_mode} eq 'local' && scalar(@users) == 0);
  my $str = $cfg_delim_begin;
  if ($self->{_auth_mode} eq 'local') {
    while (scalar(@users) > 0) {
      my $user = shift @users;
      my $pass = shift @users;
      my $disable = shift @users;
      my $ip = shift @users;
      if ($disable eq 'disable') {
        my $cmd = "/opt/vyatta/bin/sudo-users/vyatta-kick-ravpn.pl" .
                  " --username=\"$user\" --protocol=\"l2tp\"  2> /dev/null";
        system ("$cmd");
      } else {
        if ($ip eq 'none') {
            $str .= ("\n$user\t" . 'xl2tpd' . "\t\"$pass\"\t" . '*');
        }
        else {
            $str .= ("\n$user\t" . 'xl2tpd' . "\t\"$pass\"\t" . "$ip");
        }
      }
    }
  }
  $str .= "\n$cfg_delim_end\n";
  return ($str, undef);
}

sub get_ppp_opts {
  my ($self) = @_;
  my @dns = @{$self->{_dns}};
  my @wins = @{$self->{_wins}};
  my $sstr = '';
  foreach my $d (@dns) {
    $sstr .= ('ms-dns ' . "$d\n");
  }
  foreach my $w (@wins) {
    $sstr .= ('ms-wins ' . "$w\n");
  }
  my $rstr = '';
  if ($self->{_auth_mode} eq 'radius') {
    $rstr =<<EOS;
plugin radius.so
radius-config-file /etc/radiusclient/radiusclient-l2tp.conf
plugin radattr.so
EOS
  }
  my $str =<<EOS;
$cfg_delim_begin
name xl2tpd
linkname l2tp
ipcp-accept-local
ipcp-accept-remote
${sstr}noccp
auth
crtscts
nodefaultroute
debug
lock
proxyarp
connect-delay 5000
EOS
  if (defined ($self->{_auth_require})){
    $str .= "require-".$self->{_auth_require}."\n";
  }
  if (defined ($self->{_idle})){
    $str .= "idle $self->{_idle}\n"
  } else {
    $str .= "idle 1800\n";
  }
  if (defined ($self->{_mtu})){
    $str .= "mtu $self->{_mtu}\n"
         .  "mru $self->{_mtu}\n";
  }
  $str .= "${rstr}$cfg_delim_end\n";
  return ($str, undef);
}

sub get_radius_conf {
  my ($self) = @_;
  my $mode = $self->{_auth_mode};
  return ("$cfg_delim_begin\n$cfg_delim_end\n", undef) if ($mode ne 'radius');

  my @auths = @{$self->{_auth_radius}};
  return (undef, "No Radius servers specified") if ((scalar @auths) <= 0);

  my $authstr = '';
  foreach my $auth (@auths) {
    $authstr .= "authserver      $auth\n";
  }
  my $bindaddr = $self->{_radius_source};
  my $acctstr = $authstr;
  $acctstr =~ s/auth/acct/g;

  my $str =<<EOS;
$cfg_delim_begin
auth_order      radius
login_tries     4
login_timeout   60
nologin /etc/nologin
issue   /etc/radiusclient/issue
${authstr}${acctstr}servers         /etc/radiusclient/servers-l2tp
dictionary      /etc/radiusclient/dictionary-ravpn
login_radius    /usr/sbin/login.radius
seqfile         /var/run/radius.seq
mapfile         /etc/radiusclient/port-id-map-ravpn
default_realm
radius_timeout  10
radius_retries  3
login_local     /bin/login
bindaddr        ${bindaddr}
$cfg_delim_end
EOS
  return ($str, undef);
}

sub get_radius_keys {
  my ($self) = @_;
  my $mode = $self->{_auth_mode};
  return ("$cfg_delim_begin\n$cfg_delim_end\n", undef) if ($mode ne 'radius');

  my @auths = @{$self->{_auth_radius}};
  return (undef, "No Radius servers specified") if ((scalar @auths) <= 0);
  my @skeys = @{$self->{_auth_radius_keys}};
  return (undef, "Key must be specified for Radius server")
    if ((scalar @auths) != (scalar @skeys));

  my $str = $cfg_delim_begin;
  while ((scalar @auths) > 0) {
    my $auth = shift @auths;
    my $skey = shift @skeys;
    $str .= "\n$auth                $skey";
  }
  $str .= "\n$cfg_delim_end\n";
  return ($str, undef);
}

sub get_l2tp_conf {
  my ($self, $ppp_opts) = @_;
  my $oaddr = $self->{_out_addr};
  if (defined($self->{_dhcp_if})){
    return  (undef, "The specified interface is not configured for DHCP")
      if (!Vyatta::Misc::is_dhcp_enabled($self->{_dhcp_if},0));
    my $dhcpif = $self->{_dhcp_if};
    $oaddr = get_dhcp_addr($dhcpif);
  }
  return (undef, 'Outside address not defined') if (!defined($oaddr));
  my $cstart = $self->{_client_ip_start};
  return (undef, 'Client IP pool start not defined') if (!defined($cstart));
  my $cstop = $self->{_client_ip_stop};
  return (undef, 'Client IP pool stop not defined') if (!defined($cstop));
  my $ip1 = new NetAddr::IP "$cstart/32";
  my $ip2 = new NetAddr::IP "$cstop/32";
  return (undef, 'Stop IP must be higher than start IP') if ($ip1 >= $ip2);

  my $pptp = new Vyatta::Config;
  my $p1 = $pptp->returnValue('vpn pptp remote-access client-ip-pool start');
  my $p2 = $pptp->returnValue('vpn pptp remote-access client-ip-pool stop');
  if (defined($p1) && defined($p2)) {
    my $ipp1 = new NetAddr::IP "$p1/32";
    my $ipp2 = new NetAddr::IP "$p2/32";
    return (undef, 'L2TP and PPTP client IP pools overlap')
      if (!(($ip1 > $ipp2) || ($ip2 < $ipp1)));
  }

  my $str =<<EOS;
;$cfg_delim_begin
[global]
listen-addr = $oaddr

[lns default]
ip range = $cstart-$cstop
local ip = 10.255.255.0
refuse pap = yes
require authentication = yes
name = VyOSL2TPServer
ppp debug = yes
pppoptfile = $ppp_opts
length bit = yes
;$cfg_delim_end
EOS
  return ($str, undef);
}
sub get_dhcp_hook {
  my ($self, $dhcp_hook) = @_;
  return ("", undef) if (!defined($self->{_dhcp_if}));
  if (defined($self->{_dhcp_if}) && defined($self->{_out_addr})){
   return (undef, "Only one of dhcp-interface and outside-address can be defined.");
  }
  my $str =<<EOS;
#!/bin/sh
$cfg_delim_begin
CFGIFACE=$self->{_dhcp_if}
/opt/vyatta/bin/sudo-users/vyatta-l2tp-dhcp.pl --config_iface=\"\$CFGIFACE\" --interface=\"\$interface\" --new_ip=\"\$new_ip_address\" --reason=\"\$reason\" --old_ip=\"\$old_ip_address\"
$cfg_delim_end
EOS
  return ($str, undef);

}


sub removeCfg {
  my ($self, $file) = @_;
  system("sed -i '/$cfg_delim_begin/,/$cfg_delim_end/d' $file");
  if ($? >> 8) {
    print STDERR <<EOM;
L2TP VPN configuration error: Cannot remove old config from $file.
EOM
    return 0;
  }
  return 1;
}

sub writeCfg {
  my ($self, $file, $cfg, $append, $delim) = @_;
  my $op = ($append) ? '>>' : '>';
  my $WR = undef;
  if (!open($WR, "$op","$file")) {
    print STDERR <<EOM;
L2TP VPN configuration error: Cannot write config to $file.
EOM
    return 0;
  }
  if ($delim) {
    $cfg = "$cfg_delim_begin\n" . $cfg . "\n$cfg_delim_end\n";
  }
  print ${WR} "$cfg";
  close $WR;
  return 1;
}

sub maybeClustering {
  my ($self, $config, @interfaces) = @_;
  return 0 if (defined($self->{_dhcp_if}));
  return (!(Vyatta::Misc::isIPinInterfaces($config, $self->{_out_addr},
                                         @interfaces)));
}

sub print_str {
  my ($self) = @_;
  my $str = 'l2tp vpn';
  $str .= "\n  psk " . $self->{_psk};
  $str .= "\n  oaddr " . $self->{_out_addr};
  $str .= "\n  onexthop " . $self->{_out_nexthop};
  $str .= "\n  cip_start " . $self->{_client_ip_start};
  $str .= "\n  cip_stop " . $self->{_client_ip_stop};
  $str .= "\n  auth_mode " . $self->{_auth_mode};
  $str .= "\n  auth_local " . (join ",", @{$self->{_auth_local}});
  $str .= "\n  auth_radius " . (join ",", @{$self->{_auth_radius}});
  $str .= "\n  auth_radius_s " . (join ",", @{$self->{_auth_radius_keys}});
  $str .= "\n  dns " . (join ",", @{$self->{_dns}});
  $str .= "\n  wins " . (join ",", @{$self->{_wins}});
  $str .= "\n  empty " . $self->{_is_empty};
  $str .= "\n";

  return $str;
}

1;
