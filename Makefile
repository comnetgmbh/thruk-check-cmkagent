POD2README = pod2readme

all: README

README: lib/Thruk/Controller/CheckCmkAgent.pm
	$(POD2README) $<

