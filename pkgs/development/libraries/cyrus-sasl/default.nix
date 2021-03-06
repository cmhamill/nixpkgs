{ lib, stdenv, fetchurl, openssl, openldap, kerberos, db, gettext,
  pam, fixDarwinDylibNames, autoreconfHook, fetchpatch, enableLdap ? false }:

with stdenv.lib;
stdenv.mkDerivation rec {
  name = "cyrus-sasl-${version}${optionalString (kerberos == null) "-without-kerberos"}";
  version = "2.1.26";

  src = fetchurl {
    url = "ftp://ftp.cyrusimap.org/cyrus-sasl/${name}.tar.gz";
    sha256 = "1hvvbcsg21nlncbgs0cgn3iwlnb3vannzwsp6rwvnn9ba4v53g4g";
  };

  outputs = [ "bin" "dev" "out" "man" "devdoc" ];

  buildInputs =
    [ openssl db gettext kerberos ]
    ++ lib.optional enableLdap openldap
    ++ lib.optional stdenv.isFreeBSD autoreconfHook
    ++ lib.optional stdenv.isLinux pam
    ++ lib.optional stdenv.isDarwin fixDarwinDylibNames;

  patches = [
    ./missing-size_t.patch # https://bugzilla.redhat.com/show_bug.cgi?id=906519
    (fetchpatch { # CVE-2013-4122
      url = "http://sourceforge.net/projects/miscellaneouspa/files/glibc217/cyrus-sasl-2.1.26-glibc217-crypt.diff";
      sha256 = "05l7dh1w9d5fvzg0pjwzqh0fy4ah8y5cv6v67s4ssbq8xwd4pkf2";
    })
  ] ++ lib.optional stdenv.isFreeBSD (
      fetchurl {
        url = "http://www.linuxfromscratch.org/patches/blfs/svn/cyrus-sasl-2.1.26-fixes-3.patch";
        sha256 = "1vh4pc2rxxm6yvykx0b7kg09jbcwcxwv5rs6yq2ag3y8p6a9x86w";
      }
    );

  configureFlags = [
    "--with-openssl=${openssl.dev}"
  ] ++ lib.optional enableLdap "--with-ldap=${openldap.dev}";

  # Set this variable at build-time to make sure $out can be evaluated.
  preConfigure = ''
    configureFlagsArray=( --with-plugindir=$out/lib/sasl2
                          --with-saslauthd=/run/saslauthd
                          --enable-login
                        )
  '';

  installFlags = lib.optional stdenv.isDarwin [ "framedir=$(out)/Library/Frameworks/SASL2.framework" ];

  postInstall = ''
    for f in $out/lib/*.la $out/lib/sasl2/*.la; do
      substituteInPlace $f --replace "${openssl.dev}/lib" "${openssl.out}/lib"
    done
  '';

  meta = {
    homepage = http://cyrusimap.web.cmu.edu/;
    description = "Library for adding authentication support to connection-based protocols";
    platforms = platforms.unix;
  };
}
