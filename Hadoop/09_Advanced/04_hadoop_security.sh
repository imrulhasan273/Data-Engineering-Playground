#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 04_hadoop_security.sh — Hadoop Security: Kerberos, Ranger, Knox, Wire Encryption
#
# NOTE: Security configuration requires cluster-level changes.
#       This script documents commands and configuration — most sections
#       are conceptual/reference for production clusters.
#       The Docker playground cluster does NOT have Kerberos enabled.
# ─────────────────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════"
echo "  Hadoop Security Reference"
echo "════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1: Kerberos Authentication
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[1] Kerberos Overview"
echo ""
echo "  Kerberos is the primary authentication mechanism for secure Hadoop clusters."
echo "  Without Kerberos: any user can impersonate any other user (no authentication)."
echo ""
echo "  Key Concepts:"
echo "    KDC      — Key Distribution Center: issues tickets (usually MIT Kerberos or AD)"
echo "    Principal — identity: user@REALM or service/host@REALM"
echo "    Keytab   — file containing encrypted credentials (used for non-interactive auth)"
echo "    Ticket   — time-limited credential proving identity"
echo "    TGT      — Ticket-Granting Ticket: obtained at login"
echo "    kinit    — acquire a TGT"
echo "    klist    — list current tickets"
echo "    kdestroy — destroy current tickets"
echo ""
echo "  Principals in Hadoop cluster:"
echo "    hdfs/namenode.example.com@EXAMPLE.COM"
echo "    yarn/resourcemanager.example.com@EXAMPLE.COM"
echo "    hive/hiveserver.example.com@EXAMPLE.COM"
echo "    HTTP/namenode.example.com@EXAMPLE.COM   (SPNEGO for web UIs)"
echo "    alice@EXAMPLE.COM                        (user principal)"

echo -e "\n[1a] Kerberos client commands"
echo ""
echo "  # Login interactively (prompts for password)"
echo "  kinit alice@EXAMPLE.COM"
echo ""
echo "  # Login using keytab (non-interactive — for services/cron)"
echo "  kinit -kt /etc/security/keytabs/hdfs.keytab hdfs/namenode.example.com@EXAMPLE.COM"
echo ""
echo "  # List current tickets"
echo "  klist"
echo "  klist -e    # show encryption types"
echo ""
echo "  # Destroy tickets (logout)"
echo "  kdestroy"
echo ""
echo "  # Renew ticket before expiry"
echo "  kinit -R"
echo ""
echo "  # Check if Kerberos is configured on this cluster"
hadoop version 2>/dev/null | head -1
hdfs getconf -confKey hadoop.security.authentication 2>/dev/null \
  && echo "  hadoop.security.authentication = $(hdfs getconf -confKey hadoop.security.authentication 2>/dev/null)" \
  || echo "  hadoop.security.authentication = simple (Kerberos NOT enabled)"

echo -e "\n[1b] core-site.xml — Enable Kerberos"
cat << 'CORE_XML'
  <!-- Add to core-site.xml to enable Kerberos -->
  <property>
    <name>hadoop.security.authentication</name>
    <value>kerberos</value>
  </property>
  <property>
    <name>hadoop.security.authorization</name>
    <value>true</value>
  </property>
  <property>
    <name>hadoop.rpc.protection</name>
    <value>authentication</value>
    <!-- Options: authentication (default), integrity, privacy (encrypted) -->
  </property>
CORE_XML

echo -e "\n[1c] hdfs-site.xml — HDFS Kerberos principals"
cat << 'HDFS_XML'
  <!-- NameNode principal & keytab -->
  <property>
    <name>dfs.namenode.kerberos.principal</name>
    <value>hdfs/_HOST@EXAMPLE.COM</value>
    <!-- _HOST is auto-replaced with the actual hostname -->
  </property>
  <property>
    <name>dfs.namenode.keytab.file</name>
    <value>/etc/security/keytabs/hdfs.keytab</value>
  </property>
  <!-- SPNEGO for NameNode Web UI (HTTP auth) -->
  <property>
    <name>dfs.namenode.kerberos.internal.spnego.principal</name>
    <value>HTTP/_HOST@EXAMPLE.COM</value>
  </property>
  <property>
    <name>dfs.web.authentication.kerberos.principal</name>
    <value>HTTP/_HOST@EXAMPLE.COM</value>
  </property>
  <property>
    <name>dfs.web.authentication.kerberos.keytab</name>
    <value>/etc/security/keytabs/spnego.keytab</value>
  </property>
HDFS_XML

echo -e "\n[1d] HDFS operations with Kerberos"
echo ""
echo "  # Must kinit first"
echo "  kinit -kt /etc/security/keytabs/alice.keytab alice@EXAMPLE.COM"
echo ""
echo "  # Then use HDFS normally"
echo "  hdfs dfs -ls /"
echo "  hdfs dfs -put file.txt /user/alice/"
echo ""
echo "  # Check current user identity in Hadoop"
echo "  hdfs groups"
echo "  hadoop whoami"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2: HDFS Transparent Data Encryption (TDE) + KMS
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[2] HDFS Transparent Data Encryption (TDE)"
echo ""
echo "  TDE encrypts data at rest in HDFS. Files are encrypted/decrypted"
echo "  transparently — applications see plain data, disk has encrypted blocks."
echo ""
echo "  Components:"
echo "    KMS (Key Management Server) — manages encryption keys"
echo "    Encryption Zone            — HDFS directory where all files are encrypted"
echo "    DEK (Data Encryption Key)  — per-file key, encrypted by zone key (EDEK)"
echo "    EZK (Encryption Zone Key)  — master key stored in KMS"

echo -e "\n[2a] KMS setup (hadoop-kms)"
cat << 'KMS_CONF'
  # kms-site.xml (in ${HADOOP_HOME}/etc/hadoop/)
  <property>
    <name>hadoop.kms.key.provider.uri</name>
    <value>jceks://file@/etc/hadoop/conf/kms.keystore</value>
  </property>
  <property>
    <name>hadoop.kms.authentication.type</name>
    <value>kerberos</value>
  </property>

  # core-site.xml — point Hadoop to the KMS
  <property>
    <name>hadoop.security.key.provider.path</name>
    <value>kms://http@kms-host:16000/kms</value>
  </property>
KMS_CONF

echo ""
echo "  # Start KMS"
echo "  hadoop --daemon start kms"
echo ""
echo "  # Create an encryption key in KMS"
echo "  hadoop key create mykey --size 256 --cipher AES/CTR/NoPadding"
echo ""
echo "  # List keys"
echo "  hadoop key list"
echo "  hadoop key list -metadata"
echo ""
echo "  # Create an encryption zone"
echo "  hdfs dfs -mkdir /encrypted-data"
echo "  hdfs crypto -createZone -keyName mykey -path /encrypted-data"
echo ""
echo "  # Verify zone was created"
echo "  hdfs crypto -listZones"
echo ""
echo "  # Upload a file — it's encrypted at rest automatically"
echo "  hdfs dfs -put secret_data.csv /encrypted-data/"
echo ""
echo "  # Files look normal to authorized users"
echo "  hdfs dfs -cat /encrypted-data/secret_data.csv"
echo ""
echo "  # Check file encryption info"
echo "  hdfs crypto -getFileEncryptionInfo -path /encrypted-data/secret_data.csv"
echo ""
echo "  # Rotate the encryption key (re-encrypts EDEKs, not the data)"
echo "  hadoop key roll mykey"
echo "  hdfs crypto -reencryptZone -start -path /encrypted-data"
echo "  hdfs crypto -listReencryptionStatus"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3: Apache Ranger — Fine-Grained Access Control
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[3] Apache Ranger"
echo ""
echo "  Ranger provides centralized security administration for Hadoop:"
echo "    • Row/column level security in Hive"
echo "    • Path-based access control in HDFS"
echo "    • HBase table/column family access control"
echo "    • Comprehensive audit logging"
echo "    • Policy-based (deny takes precedence over allow)"
echo ""
echo "  Architecture:"
echo "    Ranger Admin  — web UI + REST API + policy store (port 6080)"
echo "    Ranger Plugin — installed in each service (HDFS, Hive, HBase...)"
echo "    Ranger Audit  — logs to HDFS, Solr, or Elasticsearch"

echo -e "\n[3a] Ranger installation (AlmaLinux 9)"
cat << 'RANGER_INSTALL'
  # Install Java and required dependencies
  sudo dnf install -y java-11-openjdk mysql-server python3

  # Download Ranger
  wget https://archive.apache.org/dist/ranger/2.4.0/apache-ranger-2.4.0.tar.gz
  tar -xzf apache-ranger-2.4.0.tar.gz

  # Configure install.properties for RangerAdmin
  cd apache-ranger-2.4.0
  cp admin/conf/install.properties admin/conf/install.properties.bak
  # Edit: DB_FLAVOR=MYSQL, db_root_user, db_root_password, db_host, etc.

  # Setup Ranger Admin
  sudo ./setup.sh

  # Start Ranger Admin
  sudo ranger-admin start

  # Access web UI: http://localhost:6080  (admin/admin)
RANGER_INSTALL

echo -e "\n[3b] Ranger HDFS plugin configuration"
cat << 'RANGER_HDFS'
  # In ranger-hdfs-security.xml (deployed by Ranger installer):
  <property>
    <name>ranger.plugin.hdfs.service.name</name>
    <value>hadoop-hdfs</value>
  </property>
  <property>
    <name>ranger.plugin.hdfs.policy.rest.url</name>
    <value>http://ranger-admin:6080</value>
  </property>
  <property>
    <name>ranger.plugin.hdfs.policy.cache.dir</name>
    <value>/etc/hadoop/conf/ranger-hdfs-security-cache</value>
  </property>
RANGER_HDFS

echo ""
echo "  Sample Ranger policy (via REST API or web UI):"
cat << 'RANGER_POLICY'
  POST http://ranger-admin:6080/service/public/v2/api/policy
  {
    "service": "hadoop-hdfs",
    "name": "data-team-policy",
    "isEnabled": true,
    "resources": {
      "path": {"values": ["/data/sensitive/*"], "isRecursive": true}
    },
    "policyItems": [
      {
        "users": ["alice", "bob"],
        "groups": ["data-team"],
        "accesses": [
          {"type": "read",    "isAllowed": true},
          {"type": "execute", "isAllowed": true}
        ]
      }
    ],
    "denyPolicyItems": [
      {
        "users": ["untrusted-user"],
        "accesses": [{"type": "read", "isAllowed": true}]
      }
    ]
  }
RANGER_POLICY

echo ""
echo "  Ranger Hive policy examples:"
echo "    • Allow data-team to SELECT from sales.* but not salaries table"
echo "    • Mask SSN column: show only last 4 digits (XXXX-XXXX-1234)"
echo "    • Row filter: WHERE region = current_user() (row-level security)"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4: Apache Knox — Gateway / Perimeter Security
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[4] Apache Knox Gateway"
echo ""
echo "  Knox is a REST API proxy and perimeter security gateway for Hadoop."
echo "  Exposes cluster services through a single HTTPS endpoint."
echo ""
echo "  Benefits:"
echo "    • Single entry point (no need to expose NameNode, HiveServer2, etc. directly)"
echo "    • Authentication: LDAP, Kerberos, JWT, PAM"
echo "    • Authorization: ACL-based service/path access"
echo "    • SSL termination — clients use HTTPS, internal traffic can be HTTP"
echo "    • Hides cluster topology from external clients"

echo -e "\n[4a] Knox URL patterns (default gateway)"
echo ""
echo "  Knox gateway URL: https://knox-host:8443/gateway/<topology>/<service>/..."
echo ""
echo "  Examples (replacing direct cluster access):"
echo "  ┌─────────────────────────────────────────────────────────────────────────┐"
echo "  │ Service     │ Direct URL                 │ Via Knox                     │"
echo "  │ ──────────────────────────────────────────────────────────────────────  │"
echo "  │ HDFS WebUI  │ http://namenode:9870        │ https://knox:8443/gateway/   │"
echo "  │             │                             │  sandbox/hdfs                │"
echo "  │ WebHDFS     │ http://namenode:9870/webhdfs│ https://knox:8443/gateway/   │"
echo "  │             │                             │  sandbox/webhdfs/v1/         │"
echo "  │ YARN        │ http://rm:8088              │ https://knox:8443/gateway/   │"
echo "  │             │                             │  sandbox/yarn                │"
echo "  │ HiveServer2 │ jdbc:hive2://hive:10000     │ jdbc:hive2://knox:8443/...   │"
echo "  └─────────────────────────────────────────────────────────────────────────┘"
echo ""
echo "  # WebHDFS via Knox (with Basic auth)"
echo "  curl -k -u alice:password \\"
echo "    'https://knox-host:8443/gateway/sandbox/webhdfs/v1/?op=LISTSTATUS'"
echo ""
echo "  # HDFS operations via Knox"
echo "  curl -k -u alice:password -X PUT \\"
echo "    'https://knox-host:8443/gateway/sandbox/webhdfs/v1/user/alice?op=MKDIRS'"

echo -e "\n[4b] Knox topology configuration"
cat << 'KNOX_TOPOLOGY'
  <!-- File: ${KNOX_HOME}/conf/topologies/sandbox.xml -->
  <topology>
    <gateway>
      <!-- Authentication provider: LDAP -->
      <provider>
        <role>authentication</role>
        <name>ShiroProvider</name>
        <enabled>true</enabled>
        <param><name>main.ldapRealm</name><value>org.apache.knox.gateway.shirorealm.KnoxLdapRealm</value></param>
        <param><name>main.ldapRealm.userDnTemplate</name><value>uid={0},ou=people,dc=example,dc=com</value></param>
        <param><name>main.ldapRealm.contextFactory.url</name><value>ldap://ldap-host:389</value></param>
      </provider>

      <!-- Authorization: restrict services by group -->
      <provider>
        <role>authorization</role>
        <name>AclsAuthz</name>
        <enabled>true</enabled>
        <param><name>webhdfs.acl</name><value>*;data-team;*</value></param>
        <param><name>hive.acl</name><value>*;analysts;*</value></param>
      </provider>

      <!-- SSL / HTTPS identity -->
      <provider>
        <role>identity-assertion</role>
        <name>Default</name>
        <enabled>true</enabled>
      </provider>
    </gateway>

    <!-- Exposed services -->
    <service><role>NAMENODE</role><url>hdfs://namenode:9000</url></service>
    <service><role>WEBHDFS</role><url>http://namenode:9870/webhdfs</url></service>
    <service><role>RESOURCEMANAGER</role><url>http://resourcemanager:8088/ws</url></service>
    <service><role>HIVE</role><url>http://hive:10001/cliservice</url></service>
    <service><role>HBASE</role><url>http://hbase:16010</url></service>
  </topology>
KNOX_TOPOLOGY

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5: Wire Encryption (SSL/TLS)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[5] Wire Encryption (SSL/TLS)"
echo ""
echo "  Encrypts data in transit between Hadoop components."
echo ""
echo "  What to encrypt:"
echo "    • HDFS data transfer (DataNode to client): HTTP/SSL"
echo "    • RPC connections: privacy mode"
echo "    • YARN web UI: HTTPS"
echo "    • HiveServer2: SSL JDBC"
echo "    • Web UIs: HTTPS via Knox"

echo -e "\n[5a] Generate SSL certificate (self-signed for dev)"
cat << 'SSL_GEN'
  # Generate keystore for each Hadoop service host
  keytool -genkeypair \
    -keystore hadoop-keystore.jks \
    -alias hadoop-ssl \
    -keyalg RSA -keysize 2048 \
    -dname "CN=namenode.example.com, OU=Hadoop, O=Example, L=NY, ST=NY, C=US" \
    -storepass changeit \
    -validity 365

  # Export certificate
  keytool -exportcert \
    -keystore hadoop-keystore.jks \
    -alias hadoop-ssl \
    -file hadoop.crt \
    -storepass changeit

  # Import into truststore (shared across all nodes)
  keytool -importcert \
    -keystore hadoop-truststore.jks \
    -alias hadoop-ssl \
    -file hadoop.crt \
    -storepass changeit \
    -noprompt

  # Copy keystore and truststore to all nodes
  # scp hadoop-keystore.jks hadoop-truststore.jks node2:/etc/hadoop/ssl/
SSL_GEN

echo -e "\n[5b] ssl-server.xml and ssl-client.xml"
cat << 'SSL_XML'
  <!-- ssl-server.xml (on each Hadoop service node) -->
  <configuration>
    <property>
      <name>ssl.server.keystore.location</name>
      <value>/etc/hadoop/ssl/hadoop-keystore.jks</value>
    </property>
    <property>
      <name>ssl.server.keystore.password</name>
      <value>changeit</value>
    </property>
    <property>
      <name>ssl.server.truststore.location</name>
      <value>/etc/hadoop/ssl/hadoop-truststore.jks</value>
    </property>
    <property>
      <name>ssl.server.truststore.password</name>
      <value>changeit</value>
    </property>
  </configuration>

  <!-- ssl-client.xml (on each Hadoop client node) -->
  <configuration>
    <property>
      <name>ssl.client.truststore.location</name>
      <value>/etc/hadoop/ssl/hadoop-truststore.jks</value>
    </property>
    <property>
      <name>ssl.client.truststore.password</name>
      <value>changeit</value>
    </property>
  </configuration>
SSL_XML

echo -e "\n[5c] Enable HTTPS in hdfs-site.xml"
cat << 'HTTPS_XML'
  <!-- Enable HTTPS for HDFS Web UI and data transfer -->
  <property>
    <name>dfs.http.policy</name>
    <value>HTTPS_ONLY</value>
    <!-- Options: HTTP_ONLY, HTTPS_ONLY, HTTP_AND_HTTPS -->
  </property>
  <property>
    <name>dfs.datanode.https.address</name>
    <value>0.0.0.0:9865</value>
  </property>
  <property>
    <name>dfs.namenode.https-address</name>
    <value>namenode:9871</value>
  </property>

  <!-- Encrypt RPC traffic (privacy = encrypt + authenticate) -->
  <property>
    <name>hadoop.rpc.protection</name>
    <value>privacy</value>
  </property>
HTTPS_XML

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6: Security Checklist for Production
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[6] Hadoop Security Checklist"
echo ""
echo "  Authentication:"
echo "    ✓ Enable Kerberos (hadoop.security.authentication = kerberos)"
echo "    ✓ Create service principals + keytabs for all Hadoop services"
echo "    ✓ Enable SPNEGO for all Web UIs"
echo ""
echo "  Authorization:"
echo "    ✓ Enable HDFS permissions (dfs.permissions.enabled = true)"
echo "    ✓ Deploy Apache Ranger for fine-grained policies"
echo "    ✓ Enable HDFS ACLs (dfs.namenode.acls.enabled = true)"
echo ""
echo "  Encryption at rest:"
echo "    ✓ Deploy KMS and create encryption keys"
echo "    ✓ Create encryption zones for sensitive directories"
echo "    ✓ Rotate encryption keys periodically"
echo ""
echo "  Encryption in transit:"
echo "    ✓ Enable HTTPS for all Web UIs (HTTP_ONLY → HTTPS_ONLY)"
echo "    ✓ Set hadoop.rpc.protection = privacy"
echo "    ✓ Use SSL/TLS for HiveServer2 JDBC connections"
echo "    ✓ Deploy Apache Knox as HTTPS gateway"
echo ""
echo "  Audit:"
echo "    ✓ Configure Ranger audit to HDFS + Solr"
echo "    ✓ Enable HDFS audit logs"
echo "    ✓ Monitor for unusual access patterns"

echo -e "\n════════════════════════════════════════════"
echo "  Hadoop Security — DONE"
echo "════════════════════════════════════════════"
