# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-libs/libselinux/libselinux-2.3_rc1.ebuild,v 1.1 2014/04/28 19:39:01 swift Exp $

EAPI="5"
PYTHON_COMPAT=( python2_7 python3_2 python3_3 )

inherit multilib python-r1 toolchain-funcs eutils multilib-minimal

MY_P="${P//_/-}"

SEPOL_VER="2.3_rc1"

DESCRIPTION="SELinux userland library"
HOMEPAGE="http://userspace.selinuxproject.org"
SRC_URI="http://userspace.selinuxproject.org/releases/2.3-rc1/${MY_P}.tar.gz
	http://dev.gentoo.org/~swift/patches/${PN}/patchbundle-${P}.tar.gz"

LICENSE="public-domain"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="python static-libs"

RDEPEND=">=sys-libs/libsepol-${SEPOL_VER}
	>=dev-libs/libpcre-8.30-r2[static-libs?]
	python? ( ${PYTHON_DEPS} )"
DEPEND="${RDEPEND}
	virtual/pkgconfig
	python? ( >=dev-lang/swig-2.0.9 )"

S="${WORKDIR}/${MY_P}"

src_prepare() {
	EPATCH_MULTI_MSG="Applying libselinux patches ... " \
	EPATCH_SUFFIX="patch" \
	EPATCH_SOURCE="${WORKDIR}/gentoo-patches" \
	EPATCH_FORCE="yes" \
	epatch

	epatch_user

	multilib_copy_sources
}

multilib_src_compile() {
	tc-export PKG_CONFIG RANLIB
	local PCRE_CFLAGS=$(${PKG_CONFIG} libpcre --cflags)
	local PCRE_LIBS=$(${PKG_CONFIG} libpcre --libs)
	export PCRE_{CFLAGS,LIBS}

	emake \
		AR="$(tc-getAR)" \
		CC="$(tc-getCC)" \
		LIBDIR="\$(PREFIX)/$(get_libdir)" \
		SHLIBDIR="\$(DESTDIR)/$(get_libdir)" \
		LDFLAGS="-fPIC ${LDFLAGS} -pthread" \
		all

	if multilib_is_native_abi && use python; then
		building() {
			python_export PYTHON_INCLUDEDIR PYTHON_LIBPATH
			emake \
				CC="$(tc-getCC)" \
				PYINC="-I${PYTHON_INCLUDEDIR}" \
				PYTHONLIBDIR="${PYTHON_LIBPATH}" \
				PYPREFIX="${EPYTHON##*/}" \
				LDFLAGS="-fPIC ${LDFLAGS} -lpthread" \
				pywrap
		}
		python_foreach_impl building
	fi
}

multilib_src_install() {
	LIBDIR="\$(PREFIX)/$(get_libdir)" SHLIBDIR="\$(DESTDIR)/$(get_libdir)" \
		emake DESTDIR="${D}" install

	if multilib_is_native_abi && use python; then
		installation() {
			LIBDIR="\$(PREFIX)/$(get_libdir)" emake DESTDIR="${D}" install-pywrap
		}
		python_foreach_impl installation
	fi

	use static-libs || rm "${D}"/usr/lib*/*.a
}

pkg_postinst() {
	# Fix bug 473502
	for POLTYPE in ${POLICY_TYPES};
	do
		mkdir -p /etc/selinux/${POLTYPE}/contexts/files
		touch /etc/selinux/${POLTYPE}/contexts/files/file_contexts.local
	done
}
