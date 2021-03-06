# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

PYTHON_COMPAT=( python3_{4,5,6} )

FORTRAN_NEEDED=fortran
FORTRAN_STANDARD=90

inherit desktop fortran-2 python-single-r1 scons-utils toolchain-funcs

DESCRIPTION="Object-oriented tool suite for chemical kinetics, thermodynamics, and transport"
HOMEPAGE="http://www.cantera.org"
SRC_URI="https://github.com/Cantera/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="+cti fortran pch +python test"

REQUIRED_USE="
	cti? ( ${PYTHON_REQUIRED_USE} )
	python? ( cti )
	${PYTHON_REQUIRED_USE}
	"

RDEPEND="
	python? (
		dev-python/numpy[${PYTHON_USEDEP}]
	)
	sci-libs/sundials:0=
"

DEPEND="
	${RDEPEND}
	dev-cpp/eigen
	dev-libs/boost
	dev-libs/libfmt
	python? (
		dev-python/cython[${PYTHON_USEDEP}]
	)
	test? (
		>=dev-cpp/gtest-1.8.0
	)
"

PATCHES=( "${FILESDIR}/${PN}_${PV}_libdirname_variable.patch" )

pkg_setup() {
	fortran-2_pkg_setup
	python-single-r1_pkg_setup
}

src_prepare() {
	default
	# patch to work 'scons test' properly in case of set up 'renamed_shared_libraries="no"' option
	sed -i "s/, libs=\['cantera_shared'\]//" "${S}"/test_problems/SConscript || die "failed to modify 'test_problems/SConscript'"
	# patch env to pass CCACHE_DIR variable
	sed -i "s/ENV={'PATH': os.environ\['PATH'\]}/ENV={'PATH': os.environ\['PATH'\], 'CCACHE_DIR': os.environ.get('CCACHE_DIR','')}/" "${S}"/SConstruct || die "failed to modify 'SConstruct'"
}

## Full list of configuration options of Cantera is presented here:
## http://cantera.org/docs/sphinx/html/compiling/config-options.html

src_configure() {
	scons_vars=(
		CC="$(tc-getCC)"
		CXX="$(tc-getCXX)"
		cc_flags="${CXXFLAGS}"
		cxx_flags="-std=c++11"
		debug="no"
		FORTRAN="$(tc-getFC)"
		FORTRANFLAGS="${CXXFLAGS}"
		renamed_shared_libraries="no"
		use_pch=$(usex pch)
## In some cases other order can break the detection of right location of Boost: ##
		system_fmt="y"
		system_sundials="y"
		system_eigen="y"
		env_vars="all"
		extra_inc_dirs="/usr/include/eigen3"
	)
	use test || scons_vars+=( googletest="none" )

	scons_targets=(
		f90_interface=$(usex fortran y n)
		python2_package="none"
	)

	if use cti ; then
		local scons_python=$(usex python full minimal)
		scons_targets+=( python3_package="${scons_python}" python3_cmd="${EPYTHON}" )
	else
		scons_targets+=( python3_package="none" )
	fi
}

src_compile() {
	escons build "${scons_vars[@]}" "${scons_targets[@]}" prefix="/usr"
}

src_test() {
	escons test
}

src_install() {
	escons install stage_dir="${D%/}" libdirname="$(get_libdir)"
	if ! use cti ; then
		rm -r "${D%/}/usr/share/man" || die "Can't remove man files."
	else
		# Run the byte-compile of modules
		python_optimize "${D%/}/$(python_get_sitedir)/${PN}"
	fi
}

pkg_postinst() {
	if use cti && ! use python ; then
		elog "Cantera was build without 'python' use-flag therefore the CTI tool 'ck2cti'"
		elog "will convert Chemkin files to Cantera format without verification of kinetic mechanism."
	fi

	local post_msg=$(usex fortran "and Fortran " "")
	elog "C++ ${post_msg}samples are installed to '/usr/share/${PN}/samples/' directory."

	if use python ; then
		elog "Python examples are installed to '$(python_get_sitedir)/${PN}/examples/' directories."
	fi
}
