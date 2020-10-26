GIT_REPO=https://github.com/PapirusDevelopmentTeam/papirus-icon-theme.git
SUBDIRS=16x16 22x22 24x24 32x32 48x48 64x64

all: ${SUBDIRS}

$(SUBDIRS):
	@$(MAKE) --no-print-directory -C $@

.PHONY: git ${SUBDIRS}

git:
	@if test -d git; then \
	  (cd git; git pull); \
	else \
	  git clone ${GIT_REPO} git; \
	fi

