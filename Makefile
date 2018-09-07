POD2README = pod2readme

all: README description.txt

README: lib/Thruk/Controller/CheckCmkAgent.pm
	$(POD2README) $<

description.txt: lib/Thruk/Controller/CheckCmkAgent.pm Makefile
	podselect -section NAME $< | tail -n-2 > description.txt
	echo 'Url: check_cmkagent.cgi' >> description.txt

